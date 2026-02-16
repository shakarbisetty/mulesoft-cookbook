/**
 * Pattern: Regex Match and Replace
 * Category: String Operations
 * Difficulty: Intermediate
 *
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
 *   "logLine": "2026-01-15 ERROR [com.acme.api] Connection timeout after 30000ms to host db-prod-01.internal:5432"
 * }
 *
 * Output (application/json):
 * {
 *   "orderYear": "2026",
 *   "orderNumber": "00542",
 *   "orderRegion": "US",
 *   "phoneDigitsOnly": "15550123456",
 *   "emailDomain": "example.com",
 *   "logLevel": "ERROR",
 *   "logHost": "db-prod-01.internal",
 *   "logPort": "5432",
 *   "phoneMasked": "+1 (555) ***-****"
 * }
 */
%dw 2.0
output application/json
var orderMatch = payload.orderRef match /ORD-(\d{4})-(\d+)-(\w+)/
var logMatch = payload.logLine match /(\d{4}-\d{2}-\d{2})\s+(\w+)\s+\[.*?\]\s+.*?(\S+):(\d+)$/
---
{
    orderYear: orderMatch[1],
    orderNumber: orderMatch[2],
    orderRegion: orderMatch[3],
    phoneDigitsOnly: payload.phone replace /[^0-9]/ with "",
    emailDomain: (payload.email match /.*@(.+)/)[1],
    logLevel: logMatch[2],
    logHost: logMatch[3],
    logPort: logMatch[4],
    phoneMasked: payload.phone replace /(\d{3})-(\d{4})$/ with "***-****"
}

// Alternative 1 — scan for all matches (returns array of match groups):
// "Order ORD-001, ORD-002, ORD-003 confirmed" scan /ORD-(\d+)/
// Output: [["ORD-001", "001"], ["ORD-002", "002"], ["ORD-003", "003"]]

// Alternative 2 — matches (boolean check):
// "alice@example.com" matches /^[\w.]+@[\w.]+\.\w{2,}$/
// Output: true

// Alternative 3 — replace with backreference:
// "2026-01-15" replace /(\d{4})-(\d{2})-(\d{2})/ with "$2/$3/$1"
// Output: "01/15/2026"
