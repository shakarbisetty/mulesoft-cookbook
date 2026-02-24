## Worker Restart for Memory Recovery
> Schedule periodic worker restarts to reclaim memory on long-running applications.

### When to Use
- Apps with slow memory leaks that are not easily fixable
- Long-running batch processors that accumulate garbage
- Temporary workaround while investigating root cause

### Configuration / Code

**CloudHub 1.0 — Runtime Manager Schedule:**
Configure via Anypoint CLI:
```bash
anypoint-cli runtime-mgr cloudhub-application restart <app-name>
```

**CloudHub 2.0 — Rolling Restart:**
```bash
anypoint-cli runtime-mgr application restart <app-name> --target ch2
```

**Cron-based via external scheduler:**
```bash
# Restart at 3 AM UTC daily (low traffic window)
0 3 * * * anypoint-cli runtime-mgr cloudhub-application restart my-app
```

### How It Works
1. Schedule restarts during low-traffic windows
2. CloudHub 2.0 uses rolling restart — one replica at a time, zero downtime
3. Fresh JVM reclaims all accumulated memory
4. Object Store V2 state persists across restarts

### Gotchas
- CloudHub 1.0 restart causes brief downtime — use multiple workers for HA
- CloudHub 2.0 rolling restart is zero-downtime with ≥ 2 replicas
- In-memory caches are lost on restart — use persistent Object Store
- Fix the root cause — scheduled restarts are a band-aid, not a solution

### Related
- [Memory Leak Detection](../../memory/memory-leak-detection/) — finding the root cause
- [Heap Sizing vCore](../../memory/heap-sizing-vcore/) — heap tuning
