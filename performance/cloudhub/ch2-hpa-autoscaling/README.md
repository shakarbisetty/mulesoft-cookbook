## CloudHub 2.0 HPA Autoscaling
> Configure Horizontal Pod Autoscaling rules for CPU/memory-based auto-scaling.

### When to Use
- Variable traffic patterns requiring dynamic scaling
- Cost optimization — scale down during off-peak hours
- Maintaining SLA during traffic spikes

### Configuration / Code

Configure in **Runtime Manager > App Settings > Replicas**:

| Setting | Value |
|---------|-------|
| Min Replicas | 2 |
| Max Replicas | 8 |
| Target CPU | 70% |
| Scale Up Stabilization | 60s |
| Scale Down Stabilization | 300s |

### How It Works
1. CloudHub 2.0 monitors CPU utilization across replicas
2. When average CPU exceeds target (70%), new replicas are added
3. Scale-up stabilization (60s) prevents flapping on brief spikes
4. Scale-down stabilization (300s) ensures traffic drop is sustained before removing replicas

### Gotchas
- Min replicas should be ≥ 2 for high availability
- Scale-up takes 30-60 seconds — not instant; use rate limiting for burst protection
- HPA scales based on CPU only — memory-bound apps may not trigger scaling
- Each replica adds cost — set max replicas based on budget

### Related
- [vCore Sizing Matrix](../vcore-sizing-matrix/) — per-replica sizing
- [Worker Restart Memory](../worker-restart-memory/) — memory management
