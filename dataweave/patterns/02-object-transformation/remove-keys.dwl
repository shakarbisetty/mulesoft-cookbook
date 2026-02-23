/**
 * Pattern: Remove Keys
 * Category: Object Transformation
 * Difficulty: Beginner
 *
 * Description: Remove unwanted keys from an object. Use when stripping
 * sensitive data (passwords, tokens), removing internal fields before sending
 * API responses, or trimming large payloads to only the fields a consumer needs.
 *
 * Input (application/json):
 * {
 *   "customerId": "C-100",
 *   "name": "Alice Chen",
 *   "email": "alice@example.com",
 *   "passwordHash": "$2b$10$xJ8k...",
 *   "ssn": "123-45-6789",
 *   "internalNotes": "VIP customer, escalate to tier 2",
 *   "accountStatus": "active",
 *   "createdAt": "2025-03-10T08:00:00Z"
 * }
 *
 * Output (application/json):
 * {
 *   "customerId": "C-100",
 *   "name": "Alice Chen",
 *   "email": "alice@example.com",
 *   "accountStatus": "active",
 *   "createdAt": "2025-03-10T08:00:00Z"
 * }
 */
%dw 2.0
output application/json
var sensitiveFields = ["passwordHash", "ssn", "internalNotes"]
---
payload filterObject (value, key) -> !(sensitiveFields contains (key as String))

// Alternative 1 — remove a single key with the - operator:
// payload - "passwordHash" - "ssn" - "internalNotes"

// Alternative 2 — keep only specific keys (allowlist approach):
// var allowedFields = ["customerId", "name", "email", "accountStatus", "createdAt"]
// ---
// payload filterObject (value, key) -> allowedFields contains (key as String)

// Alternative 3 — remove keys matching a pattern (e.g., internal_ prefix):
// payload filterObject (value, key) ->
//     !(key as String startsWith "internal")

// Alternative 4 — remove null/empty values:
// payload filterObject (value, key) -> value != null and value != ""
