/**
 * Pattern: Cross-Reference Mapping
 * Category: Lookup & Enrichment
 * Difficulty: Advanced
 *
 * Description: Map identifiers between different systems using a cross-
 * reference table. Essential for Salesforce ↔ SAP, CRM ↔ ERP, and any
 * multi-system integration where each system has its own ID scheme.
 *
 * Input (application/json):
 * {
 *   "sourceSystem": "SALESFORCE",
 *   "targetSystem": "SAP",
 *   "records": [
 *     { "sfAccountId": "001A000001ABC123", "name": "Acme Corp", "amount": 50000 },
 *     { "sfAccountId": "001A000001DEF456", "name": "Globex Inc", "amount": 75000 },
 *     { "sfAccountId": "001A000001GHI789", "name": "Initech", "amount": 30000 }
 *   ],
 *   "crossReference": [
 *     { "salesforce": "001A000001ABC123", "sap": "KUNNR-10001", "netsuite": "NS-5001" },
 *     { "salesforce": "001A000001DEF456", "sap": "KUNNR-10002", "netsuite": "NS-5002" },
 *     { "salesforce": "001A000001XYZ999", "sap": "KUNNR-10099", "netsuite": "NS-5099" }
 *   ],
 *   "fieldMapping": {
 *     "SALESFORCE_TO_SAP": {
 *       "sfAccountId": "KUNNR",
 *       "name": "NAME1",
 *       "amount": "NETWR"
 *     }
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "mapped": [
 *     { "KUNNR": "KUNNR-10001", "NAME1": "Acme Corp", "NETWR": 50000, "_source": "001A000001ABC123" },
 *     { "KUNNR": "KUNNR-10002", "NAME1": "Globex Inc", "NETWR": 75000, "_source": "001A000001DEF456" }
 *   ],
 *   "unmapped": [
 *     { "sfAccountId": "001A000001GHI789", "name": "Initech", "reason": "No cross-reference found" }
 *   ],
 *   "summary": { "total": 3, "mapped": 2, "unmapped": 1 }
 * }
 */
%dw 2.0
import partition from dw::core::Arrays
output application/json

// Build cross-ref index: SF ID → target system ID
var systemKey = lower(payload.sourceSystem)
var targetKey = lower(payload.targetSystem)
var xrefIndex = payload.crossReference indexBy $[systemKey]
var fieldMap = payload.fieldMapping["$(payload.sourceSystem)_TO_$(payload.targetSystem)"]

// Check if a record has a cross-reference
var partitioned = payload.records partition (rec) ->
    xrefIndex[rec.sfAccountId] != null
---
{
    mapped: partitioned.success map (rec) -> do {
        var targetId = xrefIndex[rec.sfAccountId][targetKey]
        ---
        {
            (fieldMap.sfAccountId): targetId,
            (fieldMap.name): rec.name,
            (fieldMap.amount): rec.amount,
            _source: rec.sfAccountId
        }
    },
    unmapped: partitioned.failure map (rec) -> {
        sfAccountId: rec.sfAccountId,
        name: rec.name,
        reason: "No cross-reference found"
    },
    summary: {
        total: sizeOf(payload.records),
        mapped: sizeOf(partitioned.success),
        unmapped: sizeOf(partitioned.failure)
    }
}
