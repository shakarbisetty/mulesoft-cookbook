## vCore Right-Sizing Calculator
> Profile workloads by TPS, payload size, and processing overhead to select the optimal vCore size and avoid over-provisioning.

### When to Use
- Deploying a new API to CloudHub and need to pick the right vCore size
- Reviewing existing deployments for cost savings during license renewal
- Migrating from on-prem to CloudHub and translating server specs to vCores
- Experiencing performance issues and unsure if you need to scale up or optimize code

### Configuration / Code

#### vCore Sizing Formula

```
Required Memory (MB) = (TPS × Avg Payload KB × Concurrency Factor × Overhead Multiplier) / 1024

Where:
  TPS              = sustained transactions per second (not burst)
  Avg Payload KB   = average request + response payload size in KB
  Concurrency Factor = number of in-flight requests (typically 5-20)
  Overhead Multiplier = 2.5 for simple transforms, 4.0 for complex orchestration
```

#### vCore Size Reference

| vCore | Memory (MB) | CPU Share | Sustained TPS Range | Best For |
|-------|-------------|-----------|---------------------|----------|
| 0.1   | 500         | 10%       | 1-5 TPS             | Health checks, scheduled tasks, low-traffic internal APIs |
| 0.2   | 1,000       | 20%       | 5-15 TPS            | Internal CRUD APIs, file polling, lightweight proxies |
| 0.5   | 1,500       | 50%       | 15-60 TPS           | Standard experience/process APIs, moderate transformations |
| 1.0   | 3,500       | 100%      | 60-150 TPS          | High-traffic APIs, complex orchestration, batch processing |
| 2.0   | 7,500       | 200%      | 150-400 TPS         | API gateways, heavy aggregation, multi-backend orchestration |
| 4.0   | 15,000      | 400%      | 400-1000 TPS        | High-throughput event processing, large payload transformations |

#### Worked Example

**Scenario**: Customer-facing REST API doing 50 TPS with 10KB average payloads, moderate DataWeave transforms.

```
Required Memory = (50 × 10 × 10 × 3.0) / 1024
               = 15,000 / 1024
               = ~14.6 MB active processing memory

Add baseline overhead:
  - Mule runtime:        ~300 MB
  - Connectors/libs:     ~100 MB
  - GC headroom (30%):   ~125 MB
  - Active processing:   ~15 MB
  Total:                 ~540 MB

Result: 0.5 vCore (1,500 MB) provides comfortable headroom.
        0.2 vCore (1,000 MB) is possible but leaves no burst capacity.
```

#### Quick-Check CLI: Current Worker Utilization

```bash
# List all apps with their vCore allocation
anypoint-cli runtime-mgr cloudhub-application list \
  --environment Production \
  --output json | jq '.[] | {name: .domain, vcores: .workers.type.weight, count: .workers.amount}'

# Check actual CPU/memory usage via Anypoint Monitoring API
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://anypoint.mulesoft.com/monitoring/query/api/v1/organizations/$ORG_ID/environments/$ENV_ID/apps/$APP_NAME/metrics?duration=7d&metric=cpu-usage,memory-usage" \
  | jq '.[] | {metric: .name, avg: .avg, p95: .p95}'
```

#### Right-Sizing Decision Script

```bash
#!/bin/bash
# right-size-check.sh — Flag over-provisioned workers
# Requires: anypoint-cli, jq

ENV="Production"
THRESHOLD_CPU=30    # % — if avg CPU < 30%, likely over-provisioned
THRESHOLD_MEM=50    # % — if avg memory < 50%, likely over-provisioned

echo "=== Over-Provisioned Worker Report ==="
echo "Apps with avg CPU < ${THRESHOLD_CPU}% AND avg memory < ${THRESHOLD_MEM}%"
echo ""

anypoint-cli runtime-mgr cloudhub-application list \
  --environment "$ENV" --output json | jq -r '.[].domain' | while read APP; do

  CPU=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://anypoint.mulesoft.com/monitoring/query/api/v1/organizations/$ORG_ID/environments/$ENV_ID/apps/$APP/metrics?duration=7d&metric=cpu-usage" \
    | jq -r '.avg // 0')

  MEM=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "https://anypoint.mulesoft.com/monitoring/query/api/v1/organizations/$ORG_ID/environments/$ENV_ID/apps/$APP/metrics?duration=7d&metric=memory-usage" \
    | jq -r '.avg // 0')

  if (( $(echo "$CPU < $THRESHOLD_CPU" | bc -l) )) && (( $(echo "$MEM < $THRESHOLD_MEM" | bc -l) )); then
    echo "  DOWNSIZE: $APP (CPU: ${CPU}%, Mem: ${MEM}%)"
  fi
done
```

### How It Works
1. Measure sustained TPS using Anypoint Analytics or API Manager metrics over a 7-day window (avoid using peak burst as the baseline)
2. Calculate average payload size from request/response logs — include headers and serialization overhead
3. Apply the sizing formula with the appropriate overhead multiplier (2.5 for passthrough/proxy, 3.0 for moderate transforms, 4.0 for complex orchestration with multiple backend calls)
4. Add Mule runtime baseline (~300-400 MB) plus connector overhead (~50-150 MB depending on connectors used)
5. Add 30% GC headroom — the G1GC collector needs free heap to operate efficiently
6. Pick the smallest vCore size that fits the total memory requirement
7. Validate by monitoring actual CPU and memory for 2 weeks after deployment — adjust if p95 memory exceeds 80%

### Gotchas
- **Over-provisioning is the #1 cost waste** — most orgs use 1.0 vCore as the default when 0.2 or 0.5 would suffice; audit shows 60% of workers run below 30% CPU
- **Burst vs sustained traffic** — size for sustained load, not peak; CloudHub auto-restarts at OOM, so a brief spike causing one restart is cheaper than permanently over-provisioning
- **Memory ≠ performance** — a 0.1 vCore has the same Mule runtime version and features as a 4.0 vCore; the difference is throughput capacity, not functionality
- **Horizontal vs vertical scaling** — two 0.5 vCore workers (1.0 total) give you HA + load balancing; one 1.0 vCore worker gives you more memory per instance but no redundancy
- **DataWeave memory impact** — large array operations (`map`, `filter` on 100K+ records) consume significantly more memory than streaming alternatives; profile DW separately
- **Connection pools eat memory** — each HTTP requester connection pool, DB connection pool, and JMS session holds memory; 10 connectors with 20 max connections each = significant overhead

### Related
- [CloudHub vCore Sizing Matrix](../../performance/cloudhub/vcore-sizing-matrix/) — detailed performance benchmarks per vCore tier
- [CloudHub 2.0 HPA Autoscaling](../../performance/cloudhub/ch2-hpa-autoscaling/) — auto-scaling for variable workloads
- [Heap Sizing per vCore](../../performance/memory/heap-sizing-vcore/) — JVM heap tuning for each vCore size
- [API Consolidation Patterns](../api-consolidation-patterns/) — combine low-traffic APIs to reduce total vCores
- [CloudHub vs RTF vs On-Prem Cost](../cloudhub-vs-rtf-vs-onprem-cost/) — TCO comparison across deployment targets
