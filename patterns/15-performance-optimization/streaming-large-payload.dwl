/**
 * Pattern: Streaming Large Payloads with Deferred Output
 * Category: Performance & Optimization
 * Difficulty: Advanced
 *
 * Description: Process payloads larger than available memory using DW 2.7-2.11
 * streaming enhancements. Combines deferred output mode, streaming-compatible
 * functions (sum, countBy, sumBy), and lazy variable materialization to handle
 * millions of records without OutOfMemory errors.
 *
 * Input (application/json):
 * {
 *   "batchId": "BATCH-20260222",
 *   "records": [
 *     {"id": 1, "category": "A", "amount": 100.50},
 *     {"id": 2, "category": "B", "amount": 250.75},
 *     {"id": 3, "category": "A", "amount": 75.25}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "batchId": "BATCH-20260222",
 *   "totalAmount": 426.50,
 *   "recordCount": 3,
 *   "categoryBreakdown": {
 *     "A": {"count": 2, "total": 175.75},
 *     "B": {"count": 1, "total": 250.75}
 *   }
 * }
 */
%dw 2.0
// Enable deferred output for streaming — writes as data becomes available
output application/json deferred=true

// Streaming-compatible aggregation — these functions process
// elements one at a time without materializing the full array
var totalAmount = payload.records sumBy $.amount
var recordCount = sizeOf(payload.records)

// Group and aggregate by category
var grouped = payload.records groupBy $.category
---
{
    batchId: payload.batchId,
    totalAmount: totalAmount,
    recordCount: recordCount,
    categoryBreakdown: grouped mapObject (records, category) -> {
        (category): {
            count: sizeOf(records),
            total: records sumBy $.amount
        }
    }
}

// Alternative 1 — streaming CSV to JSON (millions of rows):
// %dw 2.0
// input payload application/csv streaming=true, header=true
// output application/json deferred=true
// ---
// payload map (row) -> {id: row.ID, value: row.AMOUNT as Number}

// Alternative 2 — chunked Base64 for large binary (DW 2.11):
// import toBase64 from dw::core::Binaries
// toBase64(payload)  // automatically chunks in 2.11, no memory spike

// Alternative 3 — streaming reduce with running total:
// var runningTotals = payload.records reduce (record, acc = {total: 0, items: []}) ->
//     {total: acc.total + record.amount, items: acc.items + [{id: record.id, runningTotal: acc.total + record.amount}]}
