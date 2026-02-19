/**
 * Pattern: Pattern Matching
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Use DataWeave 2.0's match/case for type-based dispatch,
 * value matching, guard conditions, and regex extraction. A powerful
 * alternative to nested if/else chains.
 *
 * Input (application/json):
 * {
 *   "events": [
 *     { "type": "order.created", "data": { "orderId": "ORD-001", "amount": 500 } },
 *     { "type": "order.cancelled", "data": { "orderId": "ORD-002", "reason": "Customer request" } },
 *     { "type": "payment.received", "data": { "paymentId": "PAY-001", "amount": 500, "method": "credit_card" } },
 *     { "type": "customer.updated", "data": { "customerId": "CUST-001", "field": "email" } },
 *     { "type": "system.health", "data": { "status": "ok", "uptime": 99.9 } }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   { "category": "ORDER", "action": "PROCESS", "priority": "NORMAL", "route": "order-queue" },
 *   { "category": "ORDER", "action": "REFUND", "priority": "HIGH", "route": "cancellation-queue" },
 *   { "category": "PAYMENT", "action": "RECONCILE", "priority": "HIGH", "route": "payment-queue" },
 *   { "category": "CUSTOMER", "action": "SYNC", "priority": "LOW", "route": "crm-queue" },
 *   { "category": "SYSTEM", "action": "LOG", "priority": "LOW", "route": "monitoring-queue" }
 * ]
 */
%dw 2.0
output application/json

// Route events using pattern matching
fun routeEvent(event: Object): Object =
    event."type" match {
        // Value matching — exact match
        case "order.created" -> {
            category: "ORDER",
            action: "PROCESS",
            priority: if (event.data.amount > 1000) "HIGH" else "NORMAL",
            route: "order-queue"
        }
        case "order.cancelled" -> {
            category: "ORDER",
            action: "REFUND",
            priority: "HIGH",
            route: "cancellation-queue"
        }
        // Guard condition — match with additional condition
        case eventType if eventType startsWith "payment." -> {
            category: "PAYMENT",
            action: "RECONCILE",
            priority: "HIGH",
            route: "payment-queue"
        }
        case eventType if eventType startsWith "customer." -> {
            category: "CUSTOMER",
            action: "SYNC",
            priority: "LOW",
            route: "crm-queue"
        }
        // Default case
        else -> {
            category: "SYSTEM",
            action: "LOG",
            priority: "LOW",
            route: "monitoring-queue"
        }
    }

---
payload.events map (event) -> routeEvent(event)

// TYPE-BASED pattern matching example:
//
// fun processValue(val: Any): String =
//     val match {
//         case is String -> "String: $(val)"
//         case is Number -> "Number: $(val as String)"
//         case is Boolean -> "Boolean: $(val as String)"
//         case is Array -> "Array with $(sizeOf(val)) items"
//         case is Object -> "Object with $(sizeOf(keysOf(val))) keys"
//         case is Null -> "Null value"
//         else -> "Unknown type"
//     }

// REGEX pattern matching example:
//
// fun parseEventType(eventType: String): Object =
//     eventType match {
//         case matches /(\w+)\.(\w+)/ -> {
//             domain: $[1],
//             action: $[2]
//         }
//         else -> { domain: "unknown", action: eventType }
//     }
