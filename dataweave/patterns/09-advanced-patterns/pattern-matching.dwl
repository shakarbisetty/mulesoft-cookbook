/**
 * Pattern: Pattern Matching
 * Category: Advanced Patterns
 * Difficulty: Advanced
 * Description: Use DataWeave 2.0's match/case for type-based dispatch,
 * value matching, guard conditions, and regex extraction. A powerful
 * alternative to nested if/else chains.
 *
 * Input (application/json):
 * {
 *   "events": [
 *     {
 *       "type": "order.created",
 *       "data": {
 *         "id": "O1"
 *       }
 *     },
 *     {
 *       "type": "order.cancelled",
 *       "data": {
 *         "id": "O2"
 *       }
 *     },
 *     {
 *       "type": "payment.received",
 *       "data": {
 *         "amount": 50
 *       }
 *     },
 *     {
 *       "type": "user.login",
 *       "data": {
 *         "user": "admin"
 *       }
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * { "category": "ORDER", "action": "PROCESS", "priority": "NORMAL", "route": "order-queue" },
 * { "category": "ORDER", "action": "REFUND", "priority": "HIGH", "route": "cancellation-queue" },
 * { "category": "PAYMENT", "action": "RECONCILE", "priority": "HIGH", "route": "payment-queue" },
 * { "category": "CUSTOMER", "action": "SYNC", "priority": "LOW", "route": "crm-queue" },
 * { "category": "SYSTEM", "action": "LOG", "priority": "LOW", "route": "monitoring-queue" }
 * ]
 */
%dw 2.0
output application/json
fun routeEvent(event: Object): Object =
    event."type" match {
        case "order.created" -> ({ category: "ORDER", action: "PROCESS", priority: "NORMAL" })
        case "order.cancelled" -> ({ category: "ORDER", action: "REFUND", priority: "HIGH" })
        case eventType if eventType startsWith "payment." -> ({ category: "PAYMENT", action: "RECONCILE" })
        else -> ({ category: "SYSTEM", action: "LOG", priority: "LOW" })
    }
---
payload.events map (event) -> routeEvent(event)
