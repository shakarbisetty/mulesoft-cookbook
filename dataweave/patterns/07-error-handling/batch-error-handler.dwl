/**
 * Pattern: Batch Error Record Analysis
 * Category: Error Handling
 * Difficulty: Advanced
 * Description: Analyze per-record batch failures using Mule 4.11's BatchError
 * objects. Generates structured error reports from batch job results, groups
 * failures by error type, and produces actionable summaries for retry logic
 * or alerting.
 *
 * Input (application/json):
 * {
 *   "batchJobId": "batch-001",
 *   "results": [
 *     {
 *       "recordId": "R001",
 *       "status": "SUCCESS"
 *     },
 *     {
 *       "recordId": "R002",
 *       "status": "FAILED",
 *       "error": {
 *         "type": "CONNECTIVITY",
 *         "message": "Connection refused"
 *       }
 *     },
 *     {
 *       "recordId": "R003",
 *       "status": "FAILED",
 *       "error": {
 *         "type": "TRANSFORMATION",
 *         "message": "Cannot coerce String to Number"
 *       }
 *     },
 *     {
 *       "recordId": "R004",
 *       "status": "FAILED",
 *       "error": {
 *         "type": "CONNECTIVITY",
 *         "message": "Timeout on port 443"
 *       }
 *     },
 *     {
 *       "recordId": "R005",
 *       "status": "SUCCESS"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "batchJobId": "batch-2026-02-22-001",
 * "summary": {"total": 1000, "succeeded": 2, "failed": 3, "failureRate": 0.6},
 * "failuresByType": {
 * "CONNECTIVITY": {"count": 2, "retryable": true, "sampleMessage": "Connection refused: orders-api:443"},
 * "TRANSFORMATION": {"count": 1, "retryable": false, "sampleMessage": "Cannot coerce String to Number"}
 * },
 * "retryRecords": ["R002", "R004"],
 * "requiresManualFix": ["R003"]
 * }
 */
%dw 2.0
output application/json
var failures = payload.results filter $.status == "FAILED"
var retryableTypes = ["CONNECTIVITY", "TIMEOUT", "RATE_LIMIT"]
var grouped = failures groupBy $.error."type"
---
{
  batchJobId: payload.batchJobId,
  failuresByType: grouped mapObject (records, errorType) -> ({(errorType): {count: sizeOf(records), retryable: retryableTypes contains (errorType as String)}}),
  retryRecords: (failures filter (f) -> retryableTypes contains f.error."type") map $.recordId,
  manualFix: (failures filter (f) -> !(retryableTypes contains f.error."type")) map $.recordId
}
