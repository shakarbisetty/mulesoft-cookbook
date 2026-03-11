/**
 * Pattern: Object to Array of Pairs
 * Category: Object Transformation
 * Difficulty: Beginner
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
 * { "key": "firstName", "value": "John" },
 * { "key": "lastName", "value": "Doe" },
 * { "key": "email", "value": "john@example.com" },
 * { "key": "age", "value": 30 },
 * { "key": "active", "value": true }
 * ]
 */
%dw 2.0
output application/json
---
payload pluck (value, key) -> ({
    key: key as String,
    value: value
})
