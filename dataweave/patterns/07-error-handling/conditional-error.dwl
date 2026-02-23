/**
 * Pattern: Conditional Error Handling
 * Category: Error Handling
 * Difficulty: Intermediate
 *
 * Description: Validate input data and conditionally handle errors or set
 * defaults based on business rules. Use for field-level validation, business
 * rule enforcement, and graceful degradation when input data doesn't meet
 * expected criteria.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {"orderId": "ORD-001", "customer": "Acme Corp", "amount": 5000, "currency": "USD", "priority": "high"},
 *     {"orderId": "ORD-002", "customer": "", "amount": -50, "currency": "INVALID", "priority": "low"},
 *     {"orderId": "ORD-003", "customer": "Globex Inc", "amount": 150, "currency": "EUR", "priority": null},
 *     {"orderId": "ORD-004", "customer": "Wayne Enterprises", "amount": 0, "currency": "USD", "priority": "medium"}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "validOrders": [
 *     {"orderId": "ORD-001", "customer": "Acme Corp", "amount": 5000, "currency": "USD", "priority": "HIGH", "valid": true},
 *     {"orderId": "ORD-003", "customer": "Globex Inc", "amount": 150, "currency": "EUR", "priority": "NORMAL", "valid": true}
 *   ],
 *   "invalidOrders": [
 *     {"orderId": "ORD-002", "errors": ["Customer name is required", "Amount must be positive", "Invalid currency: INVALID"]},
 *     {"orderId": "ORD-004", "errors": ["Amount must be positive"]}
 *   ]
 * }
 */
%dw 2.0
output application/json

var validCurrencies = ["USD", "EUR", "GBP", "CAD", "AUD", "JPY"]

fun validateOrder(order: Object): Array<String> = do {
    var errors = []
        ++ (if (isEmpty(order.customer)) ["Customer name is required"] else [])
        ++ (if (order.amount <= 0) ["Amount must be positive"] else [])
        ++ (if (!(validCurrencies contains order.currency)) ["Invalid currency: $(order.currency)"] else [])
    ---
    errors
}

var validated = payload.orders map (order) -> {
    order: order,
    errors: validateOrder(order)
}
---
{
    validOrders: (validated filter isEmpty($.errors)) map (v) -> {
        orderId: v.order.orderId,
        customer: v.order.customer,
        amount: v.order.amount,
        currency: v.order.currency,
        priority: upper(v.order.priority default "normal"),
        valid: true
    },
    invalidOrders: (validated filter !isEmpty($.errors)) map (v) -> {
        orderId: v.order.orderId,
        errors: v.errors
    }
}

// Alternative 1 — simple if/else validation:
// if (payload.amount > 0 and payload.amount < 1000000)
//     {status: "accepted", amount: payload.amount}
// else
//     {status: "rejected", reason: "Amount out of range"}

// Alternative 2 — using match for pattern-based validation:
// payload.status match {
//     case "active" -> {valid: true}
//     case "pending" -> {valid: true, warning: "Pending approval"}
//     case "suspended" -> {valid: false, error: "Account suspended"}
//     else -> {valid: false, error: "Unknown status"}
// }

// Alternative 3 — validation with short-circuit:
// do {
//     var checks = [
//         {test: payload.name != null, msg: "Name required"},
//         {test: payload.email matches /.*@.*/, msg: "Invalid email"}
//     ]
//     var failures = checks filter !$.test
//     ---
//     if (isEmpty(failures)) {valid: true}
//     else {valid: false, errors: failures.msg}
// }
