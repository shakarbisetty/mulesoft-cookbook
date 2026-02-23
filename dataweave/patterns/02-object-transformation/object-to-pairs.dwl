/**
 * Pattern: Object to Array of Pairs
 * Category: Object Transformation
 * Difficulty: Beginner
 *
 * Description: Convert an object into an array of key-value pair objects.
 * One of the most frequently asked questions on MuleSoft forums. Useful
 * for dynamic processing of object properties, building form data, and
 * feeding into downstream systems that expect array format.
 *
 * Input (application/json):
 * {
 *   "firstName": "John",
 *   "lastName": "Doe",
 *   "email": "john@example.com",
 *   "age": 30,
 *   "active": true
 * }
 *
 * Output (application/json):
 * [
 *   { "key": "firstName", "value": "John" },
 *   { "key": "lastName", "value": "Doe" },
 *   { "key": "email", "value": "john@example.com" },
 *   { "key": "age", "value": 30 },
 *   { "key": "active", "value": true }
 * ]
 */
%dw 2.0
output application/json
---
payload pluck (value, key) -> {
    key: key as String,
    value: value
}

// Alternative 1 — using entrySet (returns {key, value, attributes}):
// import * from dw::core::Objects
// entrySet(payload) map { key: $.key as String, value: $.value }

// Alternative 2 — pairs back to object:
// var pairs = [{"key":"a","value":1},{"key":"b","value":2}]
// pairs reduce (pair, acc = {}) -> acc ++ { (pair.key): pair.value }

// Alternative 3 — nested object to flat pairs with dot notation:
// fun flattenToPairs(obj: Object, prefix: String = ""): Array =
//     obj pluck (v, k) -> do {
//         var fullKey = if (prefix == "") k as String else "$(prefix).$(k as String)"
//         ---
//         if (v is Object) flattenToPairs(v as Object, fullKey)
//         else [{ key: fullKey, value: v }]
//     } flatMap $
