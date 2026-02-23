/**
 * Pattern: Bulk Response Builder
 * Category: API Response Patterns
 * Difficulty: Intermediate
 *
 * Description: Build a response for batch/bulk operations that reports
 * per-record success/failure status. Essential for bulk import APIs,
 * batch processing endpoints, and data sync operations.
 *
 * Input (application/json):
 * [
 *   { "id": "REC-001", "status": "SUCCESS", "data": { "name": "Alice" } },
 *   { "id": "REC-002", "status": "FAILED", "error": "Duplicate email" },
 *   { "id": "REC-003", "status": "SUCCESS", "data": { "name": "Carol" } },
 *   { "id": "REC-004", "status": "FAILED", "error": "Invalid phone format" },
 *   { "id": "REC-005", "status": "SUCCESS", "data": { "name": "Eve" } }
 * ]
 *
 * Output (application/json):
 * {
 *   "summary": {
 *     "total": 5,
 *     "successful": 3,
 *     "failed": 2,
 *     "successRate": "60.0%"
 *   },
 *   "results": [
 *     { "id": "REC-001", "status": "SUCCESS" },
 *     { "id": "REC-002", "status": "FAILED", "error": "Duplicate email" },
 *     ...
 *   ],
 *   "errors": [
 *     { "id": "REC-002", "error": "Duplicate email" },
 *     { "id": "REC-004", "error": "Invalid phone format" }
 *   ]
 * }
 */
%dw 2.0
import partition from dw::core::Arrays
output application/json

var partitioned = payload partition (item) -> item.status == "SUCCESS"
var successCount = sizeOf(partitioned.success)
var failedCount = sizeOf(partitioned.failure)
var total = sizeOf(payload)
---
{
    summary: {
        total: total,
        successful: successCount,
        failed: failedCount,
        successRate: "$(round((successCount / total) * 1000) / 10)%"
    },
    results: payload map (item) -> {
        id: item.id,
        status: item.status,
        (error: item.error) if item.status == "FAILED"
    },
    (errors: partitioned.failure map (item) -> {
        id: item.id,
        error: item.error
    }) if failedCount > 0
}

// Alternative — minimal response (just summary + errors):
// {
//     processed: total,
//     failed: failedCount,
//     errors: partitioned.failure map { id: $.id, error: $.error }
// }
