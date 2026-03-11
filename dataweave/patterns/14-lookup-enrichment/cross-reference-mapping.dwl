/**
 * Pattern: Cross-Reference Mapping
 * Category: Lookup & Enrichment
 * Difficulty: Advanced
 * Description: Map identifiers between different systems using a cross-
 * reference table. Essential for Salesforce ↔ SAP, CRM ↔ ERP, and any
 * multi-system integration where each system has its own ID scheme.
 *
 * Input (application/json):
 * {
 *   "sourceSystem": "SF",
 *   "targetSystem": "SAP",
 *   "records": [
 *     {
 *       "sfAccountId": "SF001",
 *       "name": "Acme",
 *       "amount": 5000
 *     },
 *     {
 *       "sfAccountId": "SF002",
 *       "name": "Beta",
 *       "amount": 3000
 *     },
 *     {
 *       "sfAccountId": "SF099",
 *       "name": "Ghost",
 *       "amount": 100
 *     }
 *   ],
 *   "crossReference": [
 *     {
 *       "sf": "SF001",
 *       "sap": "SAP-A1"
 *     },
 *     {
 *       "sf": "SF002",
 *       "sap": "SAP-B2"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "mapped": [
 * { "KUNNR": "KUNNR-10001", "NAME1": "Acme Corp", "NETWR": 50000, "_source": "001A000001ABC123" },
 * { "KUNNR": "KUNNR-10002", "NAME1": "Globex Inc", "NETWR": 75000, "_source": "001A000001DEF456" }
 * ],
 * "unmapped": [
 * { "sfAccountId": "001A000001GHI789", "name": "Initech", "reason": "No cross-reference found" }
 * ],
 * "summary": { "total": 3, "mapped": 2, "unmapped": 1 }
 * }
 */
%dw 2.0
import partition from dw::core::Arrays
output application/json
var xrefIndex = payload.crossReference indexBy $.sf
var parts = payload.records partition (rec) -> xrefIndex[rec.sfAccountId]?
---
{
  mapped: parts.success map (rec) -> ({
    sapId: xrefIndex[rec.sfAccountId].sap,
    name: rec.name, amount: rec.amount
  }),
  unmapped: parts.failure map {sfAccountId: $.sfAccountId, reason: "No cross-reference found"},
  summary: {total: sizeOf(payload.records), mapped: sizeOf(parts.success)}
}
