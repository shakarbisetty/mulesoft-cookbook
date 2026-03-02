## Memory Budget Breakdown
> Exact memory allocation per vCore size so you know how much heap your application actually gets

### When to Use
- Planning a new deployment and need to pick the right vCore size
- Getting OutOfMemoryError and wondering if you simply need more memory
- Trying to understand why your 0.1 vCore worker keeps crashing on moderate payloads
- Need to justify a vCore upgrade to management with real numbers
- Calculating whether your batch job fits within available heap

### The Problem

MuleSoft vCore sizes (0.1, 0.2, 0.5, 1, 2, 4) do not map 1:1 to usable heap memory. The runtime itself, class metadata, thread stacks, native memory, and garbage collection overhead all consume a portion of the total allocation. Developers who assume "0.1 vCore = 100% available for my payload" hit OOM errors that seem impossible given the advertised size.

### Memory Allocation Table

```
+----------+----------+--------+----------+----------+----------+----------+
| vCore    | Total    | Heap   | Metaspace| Thread   | Native/  | Available|
| Size     | Memory   | (-Xmx) | Max     | Stacks   | GC/Other | for Data |
+----------+----------+--------+----------+----------+----------+----------+
| 0.1      | 512 MB   | 256 MB | 64 MB    | 48 MB    | 144 MB   | ~180 MB  |
| 0.2      | 1 GB     | 512 MB | 96 MB    | 96 MB    | 320 MB   | ~360 MB  |
| 0.5      | 1.5 GB   | 768 MB | 128 MB   | 128 MB   | 476 MB   | ~540 MB  |
| 1.0      | 3 GB     | 1.5 GB | 256 MB   | 256 MB   | 1012 MB  | ~1.1 GB  |
| 2.0      | 6 GB     | 3 GB   | 384 MB   | 384 MB   | 2256 MB  | ~2.1 GB  |
| 4.0      | 12 GB    | 6 GB   | 512 MB   | 512 MB   | 5120 MB  | ~4.2 GB  |
+----------+----------+--------+----------+----------+----------+----------+

"Available for Data" = Heap minus runtime baseline (~70-80 MB for Mule engine + loaded connectors)
```

### Where the Memory Goes

#### 1. Heap Memory (-Xmx)

This is what your application code, DataWeave transformations, payloads, and object caches use.

```
Heap breakdown on a typical 1-vCore deployment:
  Mule runtime core:         ~40 MB
  Loaded connectors:         ~20-50 MB (depends on connector count)
  Spring/DI container:       ~15 MB
  Class instances:           ~10 MB
  ─────────────────────────────────
  Runtime baseline:          ~85-115 MB
  Available for payloads:    ~1.38-1.41 GB of 1.5 GB heap
```

#### 2. Metaspace (off-heap)

Stores class metadata. Grows with the number of connectors, DataWeave scripts, and Spring beans.

```bash
# Check metaspace usage on a running instance
jcmd <PID> VM.native_memory summary | grep -A 3 "Class"
```

#### 3. Thread Stacks

Each thread consumes stack memory (default 512 KB per thread on Mule 4).

```
Thread count estimate per vCore:
  0.1 vCore: ~60 threads  x 512 KB = ~30 MB
  0.2 vCore: ~80 threads  x 512 KB = ~40 MB
  0.5 vCore: ~120 threads x 512 KB = ~60 MB
  1.0 vCore: ~200 threads x 512 KB = ~100 MB
  2.0 vCore: ~350 threads x 512 KB = ~175 MB
  4.0 vCore: ~500 threads x 512 KB = ~250 MB
```

#### 4. Native Memory and GC

JIT compiler, GC bookkeeping, NIO direct buffers, and OS-level allocations.

### Diagnostic Steps

#### Step 1: Check Current Memory Usage

**On CloudHub (Runtime Manager):**
1. Navigate to Runtime Manager > Applications > your app
2. Click **Dashboard** tab
3. Look at the **Memory** graph: used heap vs. committed heap

**Via Anypoint CLI:**
```bash
anypoint-cli runtime-mgr:application:describe <app-name> | grep -i memory
```

**On-prem with jcmd:**
```bash
# Get actual heap allocation
jcmd <PID> GC.heap_info

# Get native memory breakdown (requires -XX:NativeMemoryTracking=summary at startup)
jcmd <PID> VM.native_memory summary
```

#### Step 2: Calculate Your Payload Needs

```
Formula:
  Required Heap = (Max Payload Size x Multiplier) + Runtime Baseline

DataWeave multipliers (how much heap a transform needs relative to input size):
  Simple map/filter:        2-3x input size
  groupBy or orderBy:       3-5x input size (holds full dataset in memory)
  Complex nested transforms: 4-8x input size
  XML parsing (DOM):        5-10x input size
  Streaming (repeatable):   1.5-2x input size (file-backed beyond threshold)
```

**Example calculation:**
```
Input payload: 50 MB JSON
Transform: groupBy with nested map
Multiplier: 4x
Required heap: (50 MB x 4) + 100 MB baseline = 300 MB
Minimum vCore: 0.2 (512 MB heap, ~360 MB available)
Recommended vCore: 0.5 (768 MB heap, gives headroom for GC)
```

#### Step 3: Verify with GC Logs

Add these JVM args to your CloudHub deployment:

```
-XX:+UseG1GC -Xlog:gc*:file=/tmp/gc.log:time,uptime,level,tags:filecount=5,filesize=10M
```

Then analyze:
```bash
# Quick check: peak heap usage
grep "Pause Young" gc.log | awk '{print $NF}' | sort -n | tail -5

# Check if GC is thrashing (>5% of time in GC = problem)
grep "Total time for which application threads were stopped" gc.log | tail -20
```

### The Decision Tree

```
                    What's your max payload size?
                              |
              +---------------+---------------+
              |               |               |
          < 5 MB          5-50 MB         > 50 MB
              |               |               |
        0.1 vCore       0.2-0.5 vCore    Use streaming
        (256 MB heap)    (512-768 MB)     (see streaming
              |               |            recipe)
              |               |               |
        Simple transforms?  groupBy/orderBy?  |
        Yes -> done      Yes -> go up 1 size  |
        No -> 0.2 vCore                       |
                                         1+ vCore with
                                         file-store repeatable
                                         streaming strategy
```

### Gotchas
- **CloudHub 2.0 memory limits differ from 1.0** — CH2 uses container-based isolation; the JVM sees the container limit, not the host memory. Going over triggers an OOMKilled at the container level (no heap dump).
- **DataWeave streaming does NOT eliminate memory use** — it reduces peak usage but still buffers data. A 500 MB payload with repeatable file-store streaming still needs ~50-100 MB heap for the active window.
- **Metaspace is NOT counted in heap** — you can have 200 MB free heap and still OOM if metaspace fills up. Check for `java.lang.OutOfMemoryError: Metaspace` specifically.
- **0.1 vCore is only suitable for lightweight routing** — any transform larger than a few MB will cause problems. Do not use 0.1 vCore for integration APIs that process real payloads.
- **GC overhead increases with heap size** — a 4-vCore worker with 6 GB heap can have multi-second GC pauses unless you tune G1GC regions.
- **Multiple workers multiply cost, not memory per worker** — 2 workers x 0.5 vCore gives you 2 separate 768 MB heaps, not 1 combined 1.5 GB heap.

### Related
- [OOM Diagnostic Playbook](../oom-diagnostic-playbook/) — when you're already hitting OOM
- [Streaming Strategy Decision Guide](../streaming-strategy-decision-guide/) — reduce memory with streaming
- [DataWeave OOM Debugging](../dataweave-oom-debugging/) — DataWeave-specific memory issues
- [Batch Performance Tuning](../batch-performance-tuning/) — memory math for batch jobs
