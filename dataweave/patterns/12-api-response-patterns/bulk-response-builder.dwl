/**
 * Pattern: Bulk Response Builder
 * Category: API Response Patterns
 * Difficulty: Intermediate
 * Description: Build a response for batch/bulk operations that reports
 * per-record success/failure status. Essential for bulk import APIs,
 * batch processing endpoints, and data sync operations.
 *
 * Input (application/json):
 * [
 *   {
 *     "id": "R1",
 *     "status": "SUCCESS",
 *     "data": {
 *       "ref": "A1"
 *     }
 *   },
 *   {
 *     "id": "R2",
 *     "status": "FAILED",
 *     "error": "Duplicate key"
 *   },
 *   {
 *     "id": "R3",
 *     "status": "SUCCESS",
 *     "data": {
 *       "ref": "A3"
 *     }
 *   },
 *   {
 *     "id": "R4",
 *     "status": "SUCCESS",
 *     "data": {
 *       "ref": "A4"
 *     }
 *   },
 *   {
 *     "id": "R5",
 *     "status": "FAILED",
 *     "error": "Invalid format"
 *   }
 * ]
 *
 * Output (application/json):
 * {
 * "summary": {
 * "total": 5,
 * "successful": 3,
 * "failed": 2,
 * "successRate": "60.0%"
 * },
 * "results": [
 * { "id": "REC-001", "status": "SUCCESS" },
 * { "id": "REC-002", "status": "FAILED", "error": "Duplicate email" },
 * ...
 * ],
 * "errors": [
 * { "id": "REC-002", "error": "Duplicate email" },
 * { "id": "REC-004", "error": "Invalid phone format" }
 * ]
 * }
 */
%dw 2.0
import partition from dw::core::Arrays
output application/json
var parts = payload partition (item) -> item.status == "SUCCESS"
var successCount = sizeOf(parts.success)
var total = sizeOf(payload)
---
{
  summary: {total: total, successful: successCount, failed: total - successCount, successRate: (successCount / total * 100) as String ++ "%"},
  results: payload map {id: $.id, status: $.status, (error: $.error) if $.status == "FAILED"}
}
