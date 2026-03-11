/**
 * Pattern: Rename Keys
 * Category: Object Transformation
 * Difficulty: Beginner
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
 * "firstName": "Alice",
 * "lastName": "Chen",
 * "emailAddress": "alice.chen@example.com",
 * "phoneNumber": "+1-555-0142",
 * "createdAt": "2026-01-15T10:30:00Z"
 * }
 */
%dw 2.0
import camelize from dw::core::Strings
output application/json
---
payload mapObject (value, key) -> ({(camelize(key as String)): value})
