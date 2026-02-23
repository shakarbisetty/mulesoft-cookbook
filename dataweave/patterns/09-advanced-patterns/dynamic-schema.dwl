/**
 * Pattern: Dynamic Schema Mapping
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Map data dynamically when the schema is not known at design time.
 * Use a configuration-driven approach where field mappings are defined in a
 * lookup table, allowing the same transformation logic to handle different
 * source schemas without code changes. Critical for multi-tenant integrations,
 * configurable ETL, and self-service data mapping tools.
 *
 * Input (application/json):
 * {
 *   "mappingConfig": {
 *     "fieldMappings": [
 *       {"source": "cust_id", "target": "customerId", "type": "String"},
 *       {"source": "cust_name", "target": "customerName", "type": "String"},
 *       {"source": "order_amt", "target": "orderAmount", "type": "Number"},
 *       {"source": "order_dt", "target": "orderDate", "type": "Date", "sourceFormat": "MM/dd/yyyy"},
 *       {"source": "is_priority", "target": "isPriority", "type": "Boolean"}
 *     ]
 *   },
 *   "sourceData": [
 *     {"cust_id": "C-100", "cust_name": "Acme Corp", "order_amt": "5000.50", "order_dt": "02/15/2026", "is_priority": "true"},
 *     {"cust_id": "C-200", "cust_name": "Globex Inc", "order_amt": "1250.00", "order_dt": "02/16/2026", "is_priority": "false"}
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {"customerId": "C-100", "customerName": "Acme Corp", "orderAmount": 5000.50, "orderDate": "2026-02-15", "isPriority": true},
 *   {"customerId": "C-200", "customerName": "Globex Inc", "orderAmount": 1250.00, "orderDate": "2026-02-16", "isPriority": false}
 * ]
 */
%dw 2.0
output application/json

var config = payload.mappingConfig.fieldMappings

fun coerceValue(value: String, fieldType: String, format: String = ""): Any =
    fieldType match {
        case "Number" -> value as Number
        case "Boolean" -> value as Boolean
        case "Date" ->
            if (format != "")
                (value as Date {format: format}) as String {format: "yyyy-MM-dd"}
            else value
        else -> value
    }

fun mapRecord(record: Object, mappings: Array): Object =
    {(
        mappings map (m) -> {
            (m.target): coerceValue(
                record[m.source] as String default "",
                m."type",
                m.sourceFormat default ""
            )
        }
    )}
---
payload.sourceData map (record) -> mapRecord(record, config)

// Alternative 1 — simple rename-only mapping (no type coercion):
// var fieldMap = {"cust_id": "customerId", "cust_name": "customerName"}
// ---
// payload.sourceData map (record) ->
//     record mapObject (v, k) -> {(fieldMap[k as String] default (k as String)): v}

// Alternative 2 — mapping with default values:
// config map (m) -> {
//     (m.target): record[m.source] default m.defaultValue default null
// }

// Alternative 3 — load mapping config from external file/variable:
// var config = vars.mappingConfig  // loaded from ObjectStore or properties
// ---
// payload map (record) -> mapRecord(record, config)
