/**
 * Pattern: Merge Objects
 * Category: Object Transformation
 * Difficulty: Intermediate
 *
 * Description: Merge two or more objects into one. Essential when combining data
 * from multiple API calls, enriching a record with lookup data, or assembling a
 * canonical model from different source systems. The ++ operator merges objects;
 * when keys collide, the right-hand object wins.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "customerId": "C-100",
 *     "name": "Alice Chen",
 *     "email": "alice@example.com"
 *   },
 *   "billing": {
 *     "billingAddress": "123 Main St, San Francisco, CA 94102",
 *     "paymentMethod": "credit_card",
 *     "cardLast4": "4242"
 *   },
 *   "preferences": {
 *     "language": "en",
 *     "timezone": "America/Los_Angeles",
 *     "newsletter": true
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "customerId": "C-100",
 *   "name": "Alice Chen",
 *   "email": "alice@example.com",
 *   "billingAddress": "123 Main St, San Francisco, CA 94102",
 *   "paymentMethod": "credit_card",
 *   "cardLast4": "4242",
 *   "language": "en",
 *   "timezone": "America/Los_Angeles",
 *   "newsletter": true
 * }
 */
%dw 2.0
output application/json
---
payload.customer ++ payload.billing ++ payload.preferences

// Alternative 1 — merge with override (right wins on conflict):
// var defaults = {language: "en", timezone: "UTC", newsletter: false}
// var userPrefs = {timezone: "America/Los_Angeles", newsletter: true}
// ---
// defaults ++ userPrefs
// Output: {language: "en", timezone: "America/Los_Angeles", newsletter: true}

// Alternative 2 — conditional merge (add fields only if they exist):
// payload.customer ++
//     (if (payload.billing != null) payload.billing else {}) ++
//     (if (payload.preferences != null) payload.preferences else {})

// Alternative 3 — merge an array of objects into one:
// [payload.customer, payload.billing, payload.preferences]
//     reduce (item, acc = {}) -> acc ++ item
