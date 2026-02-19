/**
 * Pattern: Response Filtering
 * Category: API Response Patterns
 * Difficulty: Intermediate
 *
 * Description: Dynamically select which fields to return based on a query
 * parameter (?fields=name,email,phone). Reduces bandwidth and improves
 * performance for mobile clients and high-volume APIs.
 *
 * Input (application/json):
 * {
 *   "id": "CUST-001",
 *   "name": "John Doe",
 *   "email": "john@example.com",
 *   "phone": "+1-555-867-5309",
 *   "address": {
 *     "street": "123 Main St",
 *     "city": "Austin",
 *     "state": "TX",
 *     "zip": "78701"
 *   },
 *   "createdAt": "2025-01-15T10:30:00Z",
 *   "tier": "gold"
 * }
 *
 * Query: ?fields=name,email,address.city
 *
 * Output (application/json):
 * {
 *   "name": "John Doe",
 *   "email": "john@example.com",
 *   "address": {
 *     "city": "Austin"
 *   }
 * }
 */
%dw 2.0
output application/json

// Parse fields parameter: "name,email,address.city" -> ["name", "email", "address.city"]
var requestedFields = (attributes.queryParams.fields default "")
    splitBy "," map trim($)

// Check if a field was requested (supports dot notation for nested fields)
fun isRequested(field: String): Boolean =
    isEmpty(requestedFields)
    or (requestedFields contains field)
    or (requestedFields some (f) -> f startsWith "$(field).")

// Extract nested field requests for a parent
fun nestedFieldsFor(parent: String): Array<String> =
    requestedFields
        filter (f) -> f startsWith "$(parent)."
        map (f) -> f[(sizeOf(parent) + 1) to -1]

// Filter object to only include requested fields
fun filterFields(obj: Object, fields: Array<String>): Object =
    if (isEmpty(fields)) obj
    else obj filterObject (value, key) ->
        fields contains (key as String)
---
if (isEmpty(requestedFields[0]))
    // No fields param — return full payload
    payload
else
    // Filter top-level fields
    payload filterObject (value, key) -> do {
        var keyStr = key as String
        ---
        isRequested(keyStr)
    } mapObject (value, key) -> do {
        var keyStr = key as String
        var nested = nestedFieldsFor(keyStr)
        ---
        if (!isEmpty(nested) and value is Object)
            { (key): filterFields(value as Object, nested) }
        else
            { (key): value }
    }

// Alternative — simple flat field filter (no nested support):
// payload filterObject (v, k) ->
//     requestedFields contains (k as String)
