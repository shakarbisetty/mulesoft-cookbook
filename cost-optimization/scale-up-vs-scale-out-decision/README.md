# Scale-Up vs Scale-Out Decision Framework

## Problem

When an application hits performance limits, teams face a binary choice: scale up (upgrade to a bigger worker) or scale out (add more workers at the same size). Picking the wrong direction wastes money. Scaling out a stateful application breaks it. Scaling up a CPU-bound, easily-parallelizable workload pays premium prices for single-threaded gains. Without a decision framework, teams default to "bigger worker" every time, which is often the most expensive option.

## Solution

A structured decision framework that evaluates workload characteristics (statefulness, parallelizability, resource bottleneck, traffic pattern) and recommends the optimal scaling direction. Includes cost comparisons showing when each approach is cheaper, plus anti-patterns that cause failures regardless of direction.

## Implementation

### Decision Matrix

```
                        Stateless              Stateful
                   ┌─────────────────┐   ┌─────────────────┐
   Parallelizable  │  SCALE OUT ✓✓   │   │  SCALE UP ✓     │
                   │  (Best case)    │   │  (Refactor first)│
                   ├─────────────────┤   ├─────────────────┤
   Sequential      │  SCALE UP ✓     │   │  SCALE UP ✓✓    │
                   │  (Check cost)   │   │  (Only option)   │
                   └─────────────────┘   └─────────────────┘
```

### Workload Classification Checklist

```dataweave
%dw 2.0
output application/json

var workload = {
    // Statefulness indicators
    usesObjectStore: true,
    usesWatermark: false,
    usesCache: true,
    hasInMemoryState: false,
    usesBatchJobState: false,

    // Parallelizability indicators
    requestsAreIndependent: true,
    noOrderingRequirement: true,
    noSharedResourceContention: false,
    idempotentOperations: true,

    // Resource profile
    primaryBottleneck: "cpu",     // cpu | memory | io | network
    trafficPattern: "spiky",      // steady | spiky | scheduled
    peakToAverageRatio: 4.5
}

var statefulScore = [
    workload.usesObjectStore,
    workload.usesWatermark,
    workload.usesCache,
    workload.hasInMemoryState,
    workload.usesBatchJobState
] filter ((item) -> item == true) then sizeOf($)

var parallelScore = [
    workload.requestsAreIndependent,
    workload.noOrderingRequirement,
    workload.noSharedResourceContention,
    workload.idempotentOperations
] filter ((item) -> item == true) then sizeOf($)
---
{
    statefulScore: statefulScore,
    parallelScore: parallelScore,
    recommendation: if (statefulScore >= 3)
        "SCALE UP - Application has significant state; horizontal scaling will cause data inconsistency"
    else if (parallelScore >= 3 and statefulScore <= 1)
        "SCALE OUT - Workload is stateless and parallelizable; add workers for linear throughput gains"
    else if (workload.primaryBottleneck == "memory")
        "SCALE UP - Memory-bound workloads benefit more from bigger workers (non-linear memory increase)"
    else if (workload.trafficPattern == "spiky" and workload.peakToAverageRatio > 3)
        "SCALE OUT - Spiky traffic benefits from horizontal elasticity; scale in during troughs"
    else
        "EVALUATE - Mixed signals; run cost comparison for both approaches"
}
```

### Cost Comparison: Scale-Up vs Scale-Out

#### Scenario: Need to handle 200 TPS for an API proxy

**Option A: Scale Up**
| Approach | vCore Size | Workers | Total vCores | Monthly Cost (est.) |
|----------|-----------|---------|--------------|-------------------|
| Current  | 0.5       | 1       | 0.5          | $750              |
| Scale Up | 1.0       | 1       | 1.0          | $1,500            |
| Scale Up | 2.0       | 1       | 2.0          | $3,000            |

**Option B: Scale Out**
| Approach  | vCore Size | Workers | Total vCores | Monthly Cost (est.) |
|-----------|-----------|---------|--------------|-------------------|
| Current   | 0.5       | 1       | 0.5          | $750              |
| Scale Out | 0.5       | 2       | 1.0          | $1,500            |
| Scale Out | 0.5       | 3       | 1.5          | $2,250            |
| Scale Out | 0.5       | 4       | 2.0          | $3,000            |

**Key insight**: For the same total vCore cost, scaling out provides better availability (worker redundancy) but scaling up provides lower latency (no load balancer hop, more memory per request).

#### When Scale-Out Wins on Cost

```
Scale-Out wins when:
  - Traffic is variable (can scale in during low periods)
  - You need high availability (2+ workers = zero-downtime deploys)
  - Workload is embarrassingly parallel (API proxies, stateless transforms)
  - You are already on the largest vCore and still need more throughput

Savings potential: 20-40% for variable traffic patterns by scaling in during off-hours
```

#### When Scale-Up Wins on Cost

```
Scale-Up wins when:
  - Memory is the bottleneck (2.0 vCore has 7.5GB vs 2x 1.0 = 7.0GB, but one JVM = less overhead)
  - Application has warmup cost (connection pools, caches, class loading)
  - Batch processing (single large worker processes faster than distributed batch)
  - You need to avoid load balancer session affinity issues

Savings potential: 15-25% less overhead vs multiple small workers (JVM base cost ~300MB each)
```

### CloudHub Scaling Configuration

#### Scale-Out (Multiple Workers)

```xml
<!-- No code change needed for stateless apps -->
<!-- Configure via Runtime Manager: Workers = 2-4, same vCore size -->
<!-- Ensure your app handles: -->

<!-- 1. No in-memory state between requests -->
<!-- 2. Distributed locking for shared resources -->
<os:object-store
    name="distributedLock"
    persistent="true"
    entryTtl="30"
    entryTtlUnit="SECONDS"/>

<!-- 3. Externalized session if needed -->
<!-- CloudHub load balancer handles round-robin distribution -->
```

#### Scale-Up Preparation

```xml
<!-- Adjust JVM and pool settings for larger worker -->
<!-- In mule-artifact.json or wrapper.conf: -->

<!-- For 2.0 vCore (7.5GB heap available): -->
<!-- -Xms4096m -Xmx4096m (let Mule manage the rest) -->

<!-- Increase thread pools proportionally -->
<configuration>
    <expression-language>
        <global-functions>
            def vcoreMultiplier() { return 2.0 } // Adjust per vCore
        </global-functions>
    </expression-language>
</configuration>
```

### Anti-Patterns

| Anti-Pattern | Direction | What Goes Wrong |
|-------------|-----------|-----------------|
| Scale out a watermarked poller | Scale Out | Multiple workers poll the same records, causing duplicates |
| Scale out with in-memory cache | Scale Out | Each worker has different cache state; inconsistent responses |
| Scale up a CPU-bound proxy | Scale Up | Paying 2x for a bigger worker when 2 small workers handle 2x traffic |
| Scale out batch processing | Scale Out | Batch job state split across workers; incomplete processing |
| Scale out without idempotency | Scale Out | Retry + multiple workers = duplicate processing |
| Scale up to handle traffic spikes | Scale Up | Paying 24/7 for peak capacity used 2 hours/day |

## How It Works

1. **Classify your workload** using the statefulness and parallelizability checklists. Score each dimension (0-5 for state, 0-4 for parallel).
2. **Identify the primary bottleneck** from Anypoint Monitoring: CPU (scale up or out), Memory (scale up), I/O (optimize first), Network (scale out).
3. **Check the anti-patterns table** to ensure your chosen direction will not cause failures.
4. **Run the cost comparison** using your actual vCore pricing and traffic patterns.
5. **For variable traffic**, scale out wins because you can reduce workers during off-hours (via Runtime Manager API or CI/CD automation), paying only for what you use.
6. **For steady traffic**, scale up is simpler and avoids distributed system complexity.

## Key Takeaways

- Stateless + parallelizable = scale out. Stateful + sequential = scale up. No exceptions.
- Scale-out provides built-in high availability; scale-up requires a standby worker for the same resilience.
- JVM overhead is ~300MB per worker; 4 workers at 0.1 vCore waste 60% of total memory on JVM baseline.
- For spiky traffic with a peak-to-average ratio above 3x, scale-out with auto-scaling saves 20-40%.
- Always eliminate the anti-patterns before scaling in either direction.

## Related Recipes

- [vcore-benchmark-by-workload](../vcore-benchmark-by-workload/) — Throughput numbers per vCore size and workload type
- [vcore-right-sizing-calculator](../vcore-right-sizing-calculator/) — Formula for initial vCore selection
- [idle-worker-detection](../idle-worker-detection/) — Detect when scaled-out workers are underutilized
- [connection-pool-tuning-by-vcore](../connection-pool-tuning-by-vcore/) — Pool sizing after scaling up
