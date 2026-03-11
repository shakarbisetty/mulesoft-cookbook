/**
 * Pattern: Conditional Error Handling
 * Category: Error Handling
 * Difficulty: Intermediate
 * Description: Validate input data and conditionally handle errors or set
 * defaults based on business rules. Use for field-level validation, business
 * rule enforcement, and graceful degradation when input data doesn't meet
 * expected criteria.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {
 *       "orderId": "ORD-001",
 *       "customer": "Acme Corp",
 *       "amount": 5000
 *     },
 *     {
 *       "orderId": "ORD-002",
 *       "customer": "",
 *       "amount": -50
 *     },
 *     {
 *       "orderId": "ORD-003",
 *       "customer": "Bolt Inc",
 *       "amount": 150
 *     },
 *     {
 *       "orderId": "ORD-004",
 *       "customer": "Delta LLC",
 *       "amount": 0
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "validOrders": [
 * {"orderId": "ORD-001", "customer": "Acme Corp", "amount": 5000, "currency": "USD", "priority": "HIGH", "valid": true},
 * {"orderId": "ORD-003", "customer": "Globex Inc", "amount": 150, "currency": "EUR", "priority": "NORMAL", "valid": true}
 * ],
 * "invalidOrders": [
 * {"orderId": "ORD-002", "errors": ["Customer name is required", "Amount must be positive", "Invalid currency: INVALID"]},
 * {"orderId": "ORD-004", "errors": ["Amount must be positive"]}
 * ]
 * }
 */
%dw 2.0
output application/json
fun validateOrder(order) =
  if (!(order.customer is String) or order.customer == "") "Missing customer"
  else if (order.amount default 0 <= 0) "Amount must be greater than 0"
  else null
var checked = payload.orders map (o) -> o ++ {error: validateOrder(o)}
---
{
  validOrders: checked filter ($.error == null) map ($ - "error"),
  invalidOrders: checked filter ($.error != null)
}
