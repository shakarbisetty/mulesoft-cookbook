/**
 * Pattern: Batch Error Record Analysis
 * Category: Error Handling
 * Difficulty: Advanced
 *
 * Description: Analyze per-record batch failures using Mule 4.11's BatchError
 * objects. Generates structured error reports from batch job results, groups
 * failures by error type, and produces actionable summaries for retry logic
 * or alerting.
 *
 * Input (application/json):
 * {
 *   "batchJobId": "batch-2026-02-22-001",
 *   "totalRecords": 1000,
 *   "results": [
 *     {"recordId": "R001", "status": "SUCCESS", "error": null},
 *     {"recordId": "R002", "status": "FAILED", "error": {"type": "CONNECTIVITY", "message": "Connection refused: orders-api:443", "step": "enrich-order"}},
 *     {"recordId": "R003", "status": "FAILED", "error": {"type": "TRANSFORMATION", "message": "Cannot coerce String to Number", "step": "transform-payload"}},
 *     {"recordId": "R004", "status": "FAILED", "error": {"type": "CONNECTIVITY", "message": "Connection refused: orders-api:443", "step": "enrich-order"}},
 *     {"recordId": "R005", "status": "SUCCESS", "error": null}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "batchJobId": "batch-2026-02-22-001",
 *   "summary": {"total": 1000, "succeeded": 2, "failed": 3, "failureRate": 0.6},
 *   "failuresByType": {
 *     "CONNECTIVITY": {"count": 2, "retryable": true, "sampleMessage": "Connection refused: orders-api:443"},
 *     "TRANSFORMATION": {"count": 1, "retryable": false, "sampleMessage": "Cannot coerce String to Number"}
 *   },
 *   "retryRecords": ["R002", "R004"],
 *   "requiresManualFix": ["R003"]
 * }
 */
%dw 2.0
output application/json

var failures = payload.results filter $.status == "FAILED"
var successes = payload.results filter $.status == "SUCCESS"

var retryableTypes = ["CONNECTIVITY", "TIMEOUT", "RATE_LIMIT"]

var grouped = failures groupBy $.error."type"

var failuresByType = grouped pluck (records, errorType) -> {
    (errorType): {
        count: sizeOf(records),
        retryable: retryableTypes contains (errorType as String),
        sampleMessage: records[0].error.message
    }
}
---
{
    batchJobId: payload.batchJobId,
    summary: {
        total: payload.totalRecords,
        succeeded: sizeOf(successes),
        failed: sizeOf(failures),
        failureRate: if (sizeOf(payload.results) > 0)
            (sizeOf(failures) / sizeOf(payload.results) * 100) round 1
            else 0
    },
    failuresByType: failuresByType reduce (item, acc = {}) -> acc ++ item,
    retryRecords: failures
        filter (f) -> retryableTypes contains f.error."type"
        map $.recordId,
    requiresManualFix: failures
        filter (f) -> !(retryableTypes contains f.error."type")
        map $.recordId
}

// Alternative 1 — per-step failure breakdown:
// var byStep = failures groupBy $.error.step
// byStep mapObject (records, step) -> {(step): sizeOf(records)}

// Alternative 2 — threshold alerting:
// var failureRate = sizeOf(failures) / payload.totalRecords
// var alert = if (failureRate > 0.05) "CRITICAL" else if (failureRate > 0.01) "WARNING" else "OK"
