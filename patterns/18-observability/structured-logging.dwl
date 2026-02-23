/**
 * Pattern: Structured Logging Inside DataWeave
 * Category: Observability
 * Difficulty: Beginner
 *
 * Description: Use DataWeave 2.10's native logging functions to add debug,
 * info, warn, and error messages directly inside transformations. Eliminates
 * the need for Set Variable + Logger workarounds. Logs appear in Mule's
 * standard log output with full context.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {"id": "ORD-001", "amount": 150.00, "status": "completed"},
 *     {"id": "ORD-002", "amount": -10.00, "status": "pending"},
 *     {"id": "ORD-003", "amount": 5000.00, "status": "completed"}
 *   ],
 *   "threshold": 1000
 * }
 *
 * Output (application/json):
 * {
 *   "processed": 3,
 *   "flagged": [
 *     {"id": "ORD-002", "reason": "negative_amount"},
 *     {"id": "ORD-003", "reason": "above_threshold"}
 *   ]
 * }
 */
%dw 2.0
output application/json

var validated = payload.orders map (order) -> do {
    var _ = logInfo("Processing order $(order.id) — amount: $(order.amount)")
    ---
    if (order.amount < 0)
        do {
            var _ = logWarn("Negative amount detected on order $(order.id): $(order.amount)")
            ---
            {id: order.id, reason: "negative_amount", flagged: true}
        }
    else if (order.amount > payload.threshold)
        do {
            var _ = logWarn("Order $(order.id) exceeds threshold: $(order.amount) > $(payload.threshold)")
            ---
            {id: order.id, reason: "above_threshold", flagged: true}
        }
    else
        do {
            var _ = logDebug("Order $(order.id) passed validation")
            ---
            {id: order.id, flagged: false}
        }
}
---
{
    processed: sizeOf(validated),
    flagged: validated filter $.flagged map (item) -> {
        id: item.id,
        reason: item.reason
    }
}

// Alternative 1 — logError for critical failures:
// var _ = logError("CRITICAL: Payment gateway returned null for order $(order.id)")

// Alternative 2 — logWith for custom log configuration:
// var _ = logWith(order, {level: "INFO", category: "order-processing"})

// Alternative 3 — inline debug (log and return the value):
// payload.orders map (order) ->
//     logDebug("Mapping order", order) then (o) -> {id: o.id, total: o.amount}
