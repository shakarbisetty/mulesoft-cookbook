## Max Failed Records
> Configure maxFailedRecords thresholds for fault-tolerant batch processing.

### When to Use
- Batch jobs where some record failures are acceptable
- You need to set a failure threshold before aborting

### Configuration / Code

```xml
<!-- Abort on first failure -->
<batch:job jobName="strict-import" maxFailedRecords="0">

<!-- Allow up to 100 failures -->
<batch:job jobName="tolerant-import" maxFailedRecords="100">

<!-- Never abort (process all records regardless) -->
<batch:job jobName="best-effort-import" maxFailedRecords="-1">
```

### How It Works
1. `maxFailedRecords="0"` — abort immediately on any failure (default)
2. `maxFailedRecords="N"` — abort after N failures
3. `maxFailedRecords="-1"` — never abort, process everything

### Gotchas
- Failed records are still counted in `on-complete` — check `payload.failedRecords`
- `-1` means unlimited failures — always set alerts on failure counts
- The abort happens after the current block completes, not mid-block

### Related
- [Batch Step Errors](../../../error-handling/async-errors/batch-step-errors/) — error handling in batch
- [Block Size Optimization](../block-size-optimization/) — block sizing
