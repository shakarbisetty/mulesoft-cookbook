/**
 * Pattern: Regex Match and Replace
 * Category: String Operations
 * Difficulty: Intermediate
 * Description: Use regular expressions to match patterns within strings, extract
 * captured groups, and perform find-and-replace. Essential for parsing
 * unstructured text, validating formats, extracting IDs from URIs, and
 * sanitizing input data.
 *
 * Input (application/json):
 * {
 *   "orderRef": "ORD-2026-00542-US",
 *   "phone": "+1 (555) 012-3456",
 *   "email": "alice.chen@example.com",
 *   "logLine": "2026-01-15 ERROR [com.acme.api] Connection timeout"
 * }
 *
 * Output (application/json):
 * {
 * "orderYear": "2026",
 * "orderNumber": "00542",
 * "orderRegion": "US",
 * "phoneDigitsOnly": "15550123456",
 * "emailDomain": "example.com",
 * "logLevel": "ERROR",
 * "logHost": "db-prod-01.internal",
 * "logPort": "5432",
 * "phoneMasked": "+1 (555) ***-****"
 * }
 */
%dw 2.0
output application/json
var orderMatch = payload.orderRef match /^ORD-(\d{4})-(\d{5})-(\w+)$/
---
{
    orderYear: orderMatch[1],
    orderNumber: orderMatch[2],
    orderRegion: orderMatch[3],
    phoneDigitsOnly: payload.phone replace /[^0-9]/ with "",
    emailDomain: (payload.email match /.*@(.+)/)[1]
}
