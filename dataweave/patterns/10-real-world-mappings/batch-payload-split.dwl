/**
 * Pattern: Batch Payload Split
 * Category: Real-World Mappings
 * Difficulty: Intermediate
 * Description: Split a large payload into smaller chunks for batch processing.
 * Many APIs and systems have payload size limits (e.g., Salesforce bulk API
 * accepts 10,000 records per batch, SAP IDoc has segment limits). This pattern
 * chunks an array into fixed-size batches for sequential or parallel processing.
 *
 * Input (application/json):
 * {
 *   "batchSize": 3,
 *   "records": [
 *     {
 *       "id": "R001",
 *       "name": "Alpha Corp",
 *       "action": "create"
 *     },
 *     {
 *       "id": "R002",
 *       "name": "Beta Inc",
 *       "action": "update"
 *     },
 *     {
 *       "id": "R003",
 *       "name": "Gamma LLC",
 *       "action": "create"
 *     },
 *     {
 *       "id": "R004",
 *       "name": "Delta Ltd",
 *       "action": "update"
 *     },
 *     {
 *       "id": "R005",
 *       "name": "Epsilon SA",
 *       "action": "delete"
 *     },
 *     {
 *       "id": "R006",
 *       "name": "Zeta GmbH",
 *       "action": "create"
 *     },
 *     {
 *       "id": "R007",
 *       "name": "Eta Corp",
 *       "action": "update"
 *     },
 *     {
 *       "id": "R008",
 *       "name": "Theta Inc",
 *       "action": "create"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "totalRecords": 8,
 * "batchSize": 3,
 * "totalBatches": 3,
 * "batches": [
 * {"batchNumber": 1, "recordCount": 3, "records": [
 * {"id": "R001", "name": "Alice Chen", "action": "upsert"},
 * {"id": "R002", "name": "Bob Martinez", "action": "upsert"},
 * {"id": "R003", "name": "Carol Nguyen", "action": "upsert"}
 * ]},
 * {"batchNumber": 2, "recordCount": 3, "records": [
 * {"id": "R004", "name": "David Kim", "action": "insert"},
 * {"id": "R005", "name": "Elena Rossi", "action": "insert"},
 * {"id": "R006", "name": "Frank Wilson", "action": "update"}
 * ]},
 * {"batchNumber": 3, "recordCount": 2, "records": [
 * {"id": "R007", "name": "Grace Lee", "action": "upsert"},
 * {"id": "R008", "name": "Henry Park", "action": "insert"}
 * ]}
 * ]
 * }
 */
%dw 2.0
import divideBy from dw::core::Arrays
output application/json
---
payload.records divideBy payload.batchSize map (batch, index) -> ({batchNumber: index + 1, recordCount: sizeOf(batch), records: batch})
