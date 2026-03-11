/**
 * Pattern: Deep Tree Traversal and Leaf Mapping
 * Category: Utility Modules
 * Difficulty: Advanced
 * Description: Use the dw::util::Tree module to traverse and transform
 * deeply nested structures without writing manual recursion. Ideal for
 * data masking (PII scrubbing), deep key renaming, and nested value
 * normalization across unknown/variable depth structures.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "Alice Chen",
 *     "ssn": "123-45-6789",
 *     "address": {
 *       "city": "Portland",
 *       "phone": "555-0123"
 *     },
 *     "orders": [
 *       {
 *         "id": "ORD-1",
 *         "creditCard": "4111-1111-1111-1111"
 *       }
 *     ]
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "customer": {
 * "name": "Alice Chen",
 * "ssn": "***-**-6789",
 * "address": {
 * "street": "742 Evergreen Terrace",
 * "city": "Springfield",
 * "phone": "***-0123"
 * },
 * "orders": [
 * {"id": "ORD-1", "creditCard": "****-****-****-1111", "amount": 99.99},
 * {"id": "ORD-2", "creditCard": "****-****-****-0004", "amount": 149.50}
 * ]
 * }
 * }
 */
%dw 2.0
import mapLeafValues from dw::util::Tree
output application/json
var piiFields = {ssn: (v) -> "***-**-$(v[-4 to -1])", creditCard: (v) -> "****-****-****-$(v[-4 to -1])", phone: (v) -> "***-$(v[-4 to -1])"}
---
payload mapLeafValues (value, path) -> do {
  var fieldName = path[-1].selector default ""
  ---
  if (piiFields[fieldName]? and (value is String)) piiFields[fieldName](value) else value
}
