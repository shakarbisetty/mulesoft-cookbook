/**
 * Pattern: Response Filtering
 * Category: API Response Patterns
 * Difficulty: Intermediate
 * Description: Dynamically select which fields to return based on a query
 * parameter (?fields=name,email,phone). Reduces bandwidth and improves
 * performance for mobile clients and high-volume APIs.
 *
 * Input (application/json):
 * {
 *   "name": "Alice Johnson",
 *   "email": "alice@example.com",
 *   "phone": "555-0101",
 *   "age": 34,
 *   "address": {
 *     "street": "100 Main St",
 *     "city": "Austin",
 *     "state": "TX",
 *     "zip": "73301"
 *   },
 *   "queryParams": {
 *     "fields": "name,email,address.city"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "name": "John Doe",
 * "email": "john@example.com",
 * "address": {
 * "city": "Austin"
 * }
 * }
 */
%dw 2.0
import some from dw::core::Arrays
output application/json
var requestedFields = (payload.queryParams.fields default "") splitBy "," map trim($)
fun isRequested(field: String): Boolean =
    isEmpty(requestedFields) or (requestedFields contains field) or (requestedFields some (f) -> f startsWith "$(field).")
---
if (isEmpty(requestedFields[0])) payload
else (payload filterObject (v, k) -> isRequested(k as String))
    mapObject (v, k) -> if (v is Object) { (k): v filterObject (sv, sk) -> requestedFields contains "$(k).$(sk)" }
    else { (k): v }
