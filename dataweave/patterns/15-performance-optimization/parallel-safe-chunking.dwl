/**
 * Pattern: Parallel-Safe Chunking
 * Category: Performance & Optimization
 * Difficulty: Advanced
 * Description: Split a large payload into balanced chunks for parallel
 * processing in batch scopes or scatter-gather. Includes chunk metadata
 * for reassembly and error tracking.
 *
 * Input (application/json):
 * {
 *   "config": {
 *     "chunkSize": 3,
 *     "batchId": "B-100"
 *   },
 *   "records": [
 *     {
 *       "id": 1,
 *       "val": "A"
 *     },
 *     {
 *       "id": 2,
 *       "val": "B"
 *     },
 *     {
 *       "id": 3,
 *       "val": "C"
 *     },
 *     {
 *       "id": 4,
 *       "val": "D"
 *     },
 *     {
 *       "id": 5,
 *       "val": "E"
 *     },
 *     {
 *       "id": 6,
 *       "val": "F"
 *     },
 *     {
 *       "id": 7,
 *       "val": "G"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "batchId": "BATCH-2026-001",
 * "totalRecords": 8,
 * "totalChunks": 3,
 * "chunks": [
 * {
 * "chunkIndex": 0,
 * "chunkSize": 3,
 * "startIndex": 0,
 * "endIndex": 2,
 * "records": [{ "id": "R001" }, { "id": "R002" }, { "id": "R003" }]
 * },
 * {
 * "chunkIndex": 1,
 * "chunkSize": 3,
 * "startIndex": 3,
 * "endIndex": 5,
 * "records": [{ "id": "R004" }, { "id": "R005" }, { "id": "R006" }]
 * },
 * {
 * "chunkIndex": 2,
 * "chunkSize": 2,
 * "startIndex": 6,
 * "endIndex": 7,
 * "records": [{ "id": "R007" }, { "id": "R008" }]
 * }
 * ]
 * }
 */
%dw 2.0
import divideBy from dw::core::Arrays
output application/json
var chunkSize = payload.config.chunkSize
var records = payload.records
var chunks = records divideBy chunkSize
---
{ batchId: payload.config.batchId, totalRecords: sizeOf(records), totalChunks: sizeOf(chunks),
  chunks: chunks map (chunk, idx) -> ({ chunkIndex: idx, chunkSize: sizeOf(chunk),
    startIndex: idx * chunkSize, endIndex: (idx * chunkSize) + sizeOf(chunk) - 1, records: chunk }) }
