/**
 * Pattern: Rename Keys
 * Category: Object Transformation
 * Difficulty: Beginner
 *
 * Description: Rename keys in an object to match a target schema. One of the
 * most common integration tasks — mapping field names between systems (e.g.,
 * Salesforce field names to SAP field names, or snake_case API responses to
 * camelCase frontend models).
 *
 * Input (application/json):
 * {
 *   "first_name": "Alice",
 *   "last_name": "Chen",
 *   "email_address": "alice.chen@example.com",
 *   "phone_number": "+1-555-0142",
 *   "created_at": "2026-01-15T10:30:00Z"
 * }
 *
 * Output (application/json):
 * {
 *   "firstName": "Alice",
 *   "lastName": "Chen",
 *   "emailAddress": "alice.chen@example.com",
 *   "phoneNumber": "+1-555-0142",
 *   "createdAt": "2026-01-15T10:30:00Z"
 * }
 */
%dw 2.0
output application/json
---
payload mapObject (value, key) -> {
    ((key as String replace /_(\w)/ with upper($[1]))): value
}

// Alternative 1 — explicit key mapping (more readable, less dynamic):
// {
//     firstName: payload.first_name,
//     lastName: payload.last_name,
//     emailAddress: payload.email_address,
//     phoneNumber: payload.phone_number,
//     createdAt: payload.created_at
// }

// Alternative 2 — rename using a lookup table:
// var keyMap = {
//     "first_name": "firstName",
//     "last_name": "lastName",
//     "email_address": "emailAddress",
//     "phone_number": "phoneNumber",
//     "created_at": "createdAt"
// }
// ---
// payload mapObject (value, key) ->
//     {(keyMap[key as String] default (key as String)): value}

// Alternative 3 — rename keys in an array of objects:
// payload map (item) -> item mapObject (value, key) -> {
//     ((key as String replace /_(\w)/ with upper($[1]))): value
// }
