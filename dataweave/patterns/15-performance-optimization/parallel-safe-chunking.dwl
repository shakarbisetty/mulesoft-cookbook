/**
 * Pattern: Parallel-Safe Chunking
 * Category: Performance & Optimization
 * Difficulty: Advanced
 *
 * Description: Split a large payload into balanced chunks for parallel
 * processing in batch scopes or scatter-gather. Includes chunk metadata
 * for reassembly and error tracking.
 *
 * Input (application/json):
 * {
 *   "config": {
 *     "chunkSize": 3,
 *     "batchId": "BATCH-2026-001"
 *   },
 *   "records": [
 *     { "id": "R001", "data": "..." },
 *     { "id": "R002", "data": "..." },
 *     { "id": "R003", "data": "..." },
 *     { "id": "R004", "data": "..." },
 *     { "id": "R005", "data": "..." },
 *     { "id": "R006", "data": "..." },
 *     { "id": "R007", "data": "..." },
 *     { "id": "R008", "data": "..." }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "batchId": "BATCH-2026-001",
 *   "totalRecords": 8,
 *   "totalChunks": 3,
 *   "chunks": [
 *     {
 *       "chunkIndex": 0,
 *       "chunkSize": 3,
 *       "startIndex": 0,
 *       "endIndex": 2,
 *       "records": [{ "id": "R001" }, { "id": "R002" }, { "id": "R003" }]
 *     },
 *     {
 *       "chunkIndex": 1,
 *       "chunkSize": 3,
 *       "startIndex": 3,
 *       "endIndex": 5,
 *       "records": [{ "id": "R004" }, { "id": "R005" }, { "id": "R006" }]
 *     },
 *     {
 *       "chunkIndex": 2,
 *       "chunkSize": 2,
 *       "startIndex": 6,
 *       "endIndex": 7,
 *       "records": [{ "id": "R007" }, { "id": "R008" }]
 *     }
 *   ]
 * }
 */
%dw 2.0
import divideBy from dw::core::Arrays
output application/json

var chunkSize = payload.config.chunkSize
var records = payload.records
var chunks = records divideBy chunkSize
---
{
    batchId: payload.config.batchId,
    totalRecords: sizeOf(records),
    totalChunks: sizeOf(chunks),
    chunks: chunks map (chunk, idx) -> {
        chunkIndex: idx,
        chunkSize: sizeOf(chunk),
        startIndex: idx * chunkSize,
        endIndex: (idx * chunkSize) + sizeOf(chunk) - 1,
        records: chunk
    }
}

// Alternative — size-based chunking (split by total payload bytes):
// Use this when individual records vary greatly in size
//
// fun chunkBySize(items: Array, maxBytes: Number): Array<Array> =
//     items reduce (item, acc = { chunks: [[]], currentSize: 0 }) ->
//         do {
//             var itemSize = sizeOf(write(item, "application/json"))
//             ---
//             if (acc.currentSize + itemSize > maxBytes)
//                 { chunks: acc.chunks << [item], currentSize: itemSize }
//             else
//                 { chunks: acc.chunks[0 to -2] << (acc.chunks[-1] << item),
//                   currentSize: acc.currentSize + itemSize }
//         }
