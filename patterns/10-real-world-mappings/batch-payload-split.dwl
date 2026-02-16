/**
 * Pattern: Batch Payload Split
 * Category: Real-World Mappings
 * Difficulty: Intermediate
 *
 * Description: Split a large payload into smaller chunks for batch processing.
 * Many APIs and systems have payload size limits (e.g., Salesforce bulk API
 * accepts 10,000 records per batch, SAP IDoc has segment limits). This pattern
 * chunks an array into fixed-size batches for sequential or parallel processing.
 *
 * Input (application/json):
 * {
 *   "batchSize": 3,
 *   "records": [
 *     {"id": "R001", "name": "Alice Chen", "action": "upsert"},
 *     {"id": "R002", "name": "Bob Martinez", "action": "upsert"},
 *     {"id": "R003", "name": "Carol Nguyen", "action": "upsert"},
 *     {"id": "R004", "name": "David Kim", "action": "insert"},
 *     {"id": "R005", "name": "Elena Rossi", "action": "insert"},
 *     {"id": "R006", "name": "Frank Wilson", "action": "update"},
 *     {"id": "R007", "name": "Grace Lee", "action": "upsert"},
 *     {"id": "R008", "name": "Henry Park", "action": "insert"}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "totalRecords": 8,
 *   "batchSize": 3,
 *   "totalBatches": 3,
 *   "batches": [
 *     {"batchNumber": 1, "recordCount": 3, "records": [
 *       {"id": "R001", "name": "Alice Chen", "action": "upsert"},
 *       {"id": "R002", "name": "Bob Martinez", "action": "upsert"},
 *       {"id": "R003", "name": "Carol Nguyen", "action": "upsert"}
 *     ]},
 *     {"batchNumber": 2, "recordCount": 3, "records": [
 *       {"id": "R004", "name": "David Kim", "action": "insert"},
 *       {"id": "R005", "name": "Elena Rossi", "action": "insert"},
 *       {"id": "R006", "name": "Frank Wilson", "action": "update"}
 *     ]},
 *     {"batchNumber": 3, "recordCount": 2, "records": [
 *       {"id": "R007", "name": "Grace Lee", "action": "upsert"},
 *       {"id": "R008", "name": "Henry Park", "action": "insert"}
 *     ]}
 *   ]
 * }
 */
%dw 2.0
output application/json

fun chunk(arr: Array, size: Number): Array<Array> =
    if (isEmpty(arr)) []
    else [arr[0 to (size - 1)]] ++ chunk(arr[size to -1] default [], size)

var records = payload.records
var batchSize = payload.batchSize
var batches = chunk(records, batchSize)
---
{
    totalRecords: sizeOf(records),
    batchSize: batchSize,
    totalBatches: sizeOf(batches),
    batches: batches map (batch, index) -> {
        batchNumber: index + 1,
        recordCount: sizeOf(batch),
        records: batch
    }
}

// Alternative 1 — chunk using divideBy (DW built-in):
// import divideBy from dw::core::Arrays
// ---
// payload.records divideBy payload.batchSize

// Alternative 2 — split by a field value (e.g., action type):
// payload.records groupBy $.action mapObject (items, action) -> {
//     (action): chunk(items, payload.batchSize)
// }

// Alternative 3 — chunk with size limit in bytes (estimate):
// fun chunkBySize(arr: Array, maxBytes: Number): Array<Array> = do {
//     var sizes = arr map sizeOf(write($, "application/json"))
//     // ... accumulate until maxBytes exceeded, then start new chunk
// }
