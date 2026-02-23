/**
 * Pattern: Recursive Transform
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Recursively traverse and transform deeply nested data structures
 * of unknown depth. Use when you need to apply a transformation to every level
 * of a nested payload — e.g., masking all PII fields, renaming keys at every
 * level, stripping nulls from arbitrarily nested objects.
 *
 * Input (application/json):
 * {
 *   "company": "Acme Corp",
 *   "ceo": {
 *     "name": "Alice Chen",
 *     "ssn": "123-45-6789",
 *     "email": "alice@acme.com",
 *     "directReports": [
 *       {
 *         "name": "Bob Martinez",
 *         "ssn": "234-56-7890",
 *         "email": "bob@acme.com",
 *         "directReports": [
 *           {"name": "Carol Nguyen", "ssn": "345-67-8901", "email": "carol@acme.com", "directReports": []},
 *           {"name": "David Kim", "ssn": "456-78-9012", "email": "david@acme.com", "directReports": []}
 *         ]
 *       },
 *       {
 *         "name": "Elena Rossi",
 *         "ssn": "567-89-0123",
 *         "email": "elena@acme.com",
 *         "directReports": []
 *       }
 *     ]
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "company": "Acme Corp",
 *   "ceo": {
 *     "name": "Alice Chen",
 *     "ssn": "***-**-6789",
 *     "email": "a****@acme.com",
 *     "directReports": [
 *       {
 *         "name": "Bob Martinez",
 *         "ssn": "***-**-7890",
 *         "email": "b****@acme.com",
 *         "directReports": [
 *           {"name": "Carol Nguyen", "ssn": "***-**-8901", "email": "c****@acme.com", "directReports": []},
 *           {"name": "David Kim", "ssn": "***-**-9012", "email": "d****@acme.com", "directReports": []}
 *         ]
 *       },
 *       {
 *         "name": "Elena Rossi",
 *         "ssn": "***-**-0123",
 *         "email": "e****@acme.com",
 *         "directReports": []
 *       }
 *     ]
 *   }
 * }
 */
%dw 2.0
output application/json

fun maskSsn(ssn: String): String =
    "***-**-" ++ ssn[-4 to -1]

fun maskEmail(email: String): String = do {
    var parts = email splitBy "@"
    ---
    parts[0][0] ++ "****@" ++ parts[1]
}

fun maskPII(data: Any): Any =
    data match {
        case obj is Object -> obj mapObject (value, key) ->
            if ((key as String) == "ssn") {(key): maskSsn(value as String)}
            else if ((key as String) == "email") {(key): maskEmail(value as String)}
            else {(key): maskPII(value)}
        case arr is Array -> arr map maskPII($)
        else -> data
    }
---
maskPII(payload)

// Alternative 1 — recursive null stripper:
// fun stripNulls(data: Any): Any =
//     data match {
//         case obj is Object -> obj mapObject (v, k) ->
//             if (v != null) {(k): stripNulls(v)} else {}
//         case arr is Array -> arr map stripNulls($)
//         else -> data
//     }

// Alternative 2 — recursive key renamer (snake_case to camelCase):
// fun camelizeKeys(data: Any): Any =
//     data match {
//         case obj is Object -> obj mapObject (v, k) -> {
//             ((k as String replace /_(\w)/ with upper($[1]))): camelizeKeys(v)
//         }
//         case arr is Array -> arr map camelizeKeys($)
//         else -> data
//     }
