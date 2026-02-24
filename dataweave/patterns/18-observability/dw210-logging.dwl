/**
 * Pattern: DW 2.10 Logging Functions
 * Category: Observability
 * Difficulty: Beginner
 * Since: DataWeave 2.10 (Mule 4.11+)
 *
 * Description: Use native DataWeave logging for debugging without side effects.
 * DW 2.10 introduces logInfo(), logDebug(), logWarn(), and logError() as
 * first-class functions. These replace the old Set Variable + Logger workaround
 * and produce zero side effects on the transformation output. Logs appear in
 * the Mule runtime log with full correlation context (flow name, correlation ID).
 *
 * Input (application/json):
 * {
 *   "customers": [
 *     {"id": "C-100", "name": "Acme Corp", "tier": "gold", "balance": 15000},
 *     {"id": "C-101", "name": "Beta Inc", "tier": "silver", "balance": -200},
 *     {"id": "C-102", "name": "Gamma LLC", "tier": "bronze", "balance": 500},
 *     {"id": "C-103", "name": "Delta Ltd", "tier": "gold", "balance": 75000}
 *   ],
 *   "creditLimit": 50000
 * }
 *
 * Output (application/json):
 * {
 *   "totalProcessed": 4,
 *   "alerts": [
 *     {"id": "C-101", "issue": "negative_balance", "balance": -200},
 *     {"id": "C-103", "issue": "over_credit_limit", "balance": 75000}
 *   ],
 *   "summary": {
 *     "gold": 2,
 *     "silver": 1,
 *     "bronze": 1
 *   }
 * }
 *
 * Log output (Mule runtime log):
 *   INFO  [dw] Processing 4 customers with credit limit 50000
 *   DEBUG [dw] Customer C-100: gold tier, balance 15000 — OK
 *   WARN  [dw] Customer C-101 has negative balance: -200
 *   DEBUG [dw] Customer C-102: bronze tier, balance 500 — OK
 *   WARN  [dw] Customer C-103 exceeds credit limit: 75000 > 50000
 *   INFO  [dw] Completed: 4 processed, 2 alerts generated
 */
%dw 2.0
output application/json

// Basic usage: logInfo() for flow-level context
var _ = logInfo("Processing $(sizeOf(payload.customers)) customers with credit limit $(payload.creditLimit)")

// Process each customer with granular logging
var results = payload.customers map (customer) -> do {
    // logDebug() for per-record tracing — disabled in production log levels
    var _ = logDebug("Evaluating customer $(customer.id): $(customer.tier) tier, balance $(customer.balance)")
    ---
    if (customer.balance < 0)
        do {
            // logWarn() for business rule violations
            var _ = logWarn("Customer $(customer.id) has negative balance: $(customer.balance)")
            ---
            {id: customer.id, issue: "negative_balance", balance: customer.balance, flagged: true}
        }
    else if (customer.balance > payload.creditLimit)
        do {
            var _ = logWarn("Customer $(customer.id) exceeds credit limit: $(customer.balance) > $(payload.creditLimit)")
            ---
            {id: customer.id, issue: "over_credit_limit", balance: customer.balance, flagged: true}
        }
    else
        do {
            var _ = logDebug("Customer $(customer.id): $(customer.tier) tier, balance $(customer.balance) — OK")
            ---
            {id: customer.id, flagged: false, tier: customer.tier}
        }
}

// Log summary before returning
var alerts = results filter $.flagged
var _ = logInfo("Completed: $(sizeOf(results)) processed, $(sizeOf(alerts)) alerts generated")
---
{
    totalProcessed: sizeOf(results),
    alerts: alerts map {
        id: $.id,
        issue: $.issue,
        balance: $.balance
    },
    summary: results groupBy $.tier mapObject (items, tier) ->
        (tier): sizeOf(items)
}

// =============================================================================
// LABELED LOGGING — add context categories for log filtering
// =============================================================================
//
// var _ = logInfo("Payment processed", {
//     category: "payments",
//     orderId: order.id,
//     amount: order.total
// })
//
// Log output:
//   INFO [dw:payments] Payment processed {orderId=ORD-001, amount=150.00}

// =============================================================================
// CONDITIONAL LOGGING — log only when a condition is met
// =============================================================================
//
// var _ = if (payload.amount > 10000)
//             logWarn("High-value transaction: $(payload.amount)")
//         else
//             logDebug("Standard transaction: $(payload.amount)")

// =============================================================================
// LOG AND PASS-THROUGH — log a value and return it unchanged
// =============================================================================
//
// // The log() function logs the value and returns it (identity + side effect)
// payload.orders map (order) ->
//     log("order-processing", order) then (o) -> {
//         id: o.id,
//         total: o.amount * o.quantity
//     }
//
// Log output:
//   DEBUG [dw:order-processing] {id: "ORD-001", amount: 19.99, quantity: 3}

// =============================================================================
// ERROR-LEVEL LOGGING — for critical failures in try/catch
// =============================================================================
//
// try(() ->
//     parseJson(payload)
// ) match {
//     case success if success.success ->
//         success.result
//     case failure -> do {
//         var _ = logError("Failed to parse payload: $(failure.error.message)")
//         ---
//         {error: "parse_failure", detail: failure.error.message}
//     }
// }

// =============================================================================
// PERFORMANCE NOTES
// =============================================================================
//
// - logDebug() calls are effectively free when log level is INFO or higher
//   (the runtime short-circuits evaluation)
// - String interpolation in log messages IS evaluated even if the log level
//   is disabled — use conditional logging for expensive string construction
// - Log functions return null — use `var _ = logInfo(...)` to discard the
//   return value cleanly
// - These functions are pure side effects in the DW engine; they do NOT
//   affect transformation output or memoization
