/**
 * Pattern: Template Strings (String Interpolation)
 * Category: String Operations
 * Difficulty: Beginner
 * Description: Build dynamic strings by embedding expressions inside string
 * literals using the $(...) interpolation syntax. Use for constructing log
 * messages, email bodies, API endpoint URLs, formatted display strings, and
 * any string that combines static text with dynamic values.
 *
 * Input (application/json):
 * {
 *   "order": {
 *     "orderId": "ORD-1587",
 *     "customer": "Alice Chen",
 *     "items": 3,
 *     "total": 249.97,
 *     "currency": "USD"
 *   },
 *   "config": {
 *     "apiBase": "https://api.acme.com",
 *     "version": "v2",
 *     "region": "us-west"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "confirmationMessage": "Thank you, Alice Chen! Your order ORD-2026-1587 with 3 items totaling $249.97 USD has been confirmed.",
 * "shippingNotice": "Order ORD-2026-1587 is scheduled for shipment on 2026-02-20.",
 * "apiEndpoint": "https://api.acme.com/v2/orders/ORD-2026-1587",
 * "logEntry": "[us-west] Processing order ORD-2026-1587 for customer Alice Chen (3 items, $249.97)"
 * }
 */
%dw 2.0
output application/json
var o = payload.order
var c = payload.config
---
{
  confirmationMessage: "Thank you, $(o.customer)! Order $(o.orderId) with $(o.items) items totaling $(o.total) $(o.currency) confirmed.",
  apiEndpoint: "$(c.apiBase)/$(c.version)/orders/$(o.orderId)",
  logEntry: "[$(c.region)] Order $(o.orderId) for $(o.customer) ($(o.items) items)"
}
