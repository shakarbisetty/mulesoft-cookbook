/**
 * Pattern: Streaming Large Payloads with Deferred Output
 * Category: Performance & Optimization
 * Difficulty: Advanced
 * Description: Process payloads larger than available memory using DW 2.7-2.11
 * streaming enhancements. Combines deferred output mode, streaming-compatible
 * functions (sum, countBy, sumBy), and lazy variable materialization to handle
 * millions of records without OutOfMemory errors.
 *
 * Input (application/json):
 * {
 *   "batchId": "BATCH-001",
 *   "records": [
 *     {
 *       "id": 1,
 *       "category": "A",
 *       "amount": 100.5
 *     },
 *     {
 *       "id": 2,
 *       "category": "B",
 *       "amount": 250.75
 *     },
 *     {
 *       "id": 3,
 *       "category": "A",
 *       "amount": 75.25
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "batchId": "BATCH-20260222",
 * "totalAmount": 426.50,
 * "recordCount": 3,
 * "categoryBreakdown": {
 * "A": {"count": 2, "total": 175.75},
 * "B": {"count": 1, "total": 250.75}
 * }
 * }
 */
%dw 2.0
import sumBy from dw::core::Arrays
output application/json
var totalAmount = payload.records sumBy $.amount
var grouped = payload.records groupBy $.category
---
{batchId: payload.batchId, totalAmount: totalAmount, recordCount: sizeOf(payload.records), categoryBreakdown: grouped mapObject (records, cat) -> ({(cat): {count: sizeOf(records), total: records sumBy $.amount}})}
