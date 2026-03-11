/**
 * Pattern: Dynamic Schema Mapping
 * Category: Advanced Patterns
 * Difficulty: Advanced
 * Description: Map data dynamically when the schema is not known at design time.
 * Use a configuration-driven approach where field mappings are defined in a
 * lookup table, allowing the same transformation logic to handle different
 * source schemas without code changes. Critical for multi-tenant integrations,
 * configurable ETL, and self-service data mapping tools.
 *
 * Input (application/json):
 * {
 *   "mappingConfig": [
 *     {
 *       "source": "cust_id",
 *       "target": "customerId"
 *     },
 *     {
 *       "source": "cust_name",
 *       "target": "customerName"
 *     },
 *     {
 *       "source": "order_amt",
 *       "target": "orderAmount"
 *     }
 *   ],
 *   "sourceData": [
 *     {
 *       "cust_id": "C-100",
 *       "cust_name": "Acme Corp",
 *       "order_amt": 5200
 *     },
 *     {
 *       "cust_id": "C-200",
 *       "cust_name": "Globex Inc",
 *       "order_amt": 3100
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * {"customerId": "C-100", "customerName": "Acme Corp", "orderAmount": 5000.50, "orderDate": "2026-02-15", "isPriority": true},
 * {"customerId": "C-200", "customerName": "Globex Inc", "orderAmount": 1250.00, "orderDate": "2026-02-16", "isPriority": false}
 * ]
 */
%dw 2.0
output application/json
var config = payload.mappingConfig
---
payload.sourceData map (record) -> ({
  (config map (field) -> ({
    (field.target): record[field.source]
  }))
})
