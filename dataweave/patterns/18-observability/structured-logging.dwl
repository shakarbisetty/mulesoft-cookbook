/**
 * Pattern: Structured Logging Inside DataWeave
 * Category: Observability
 * Difficulty: Beginner
 * Description: Use DataWeave 2.10's native logging functions to add debug,
 * info, warn, and error messages directly inside transformations. Eliminates
 * the need for Set Variable + Logger workarounds. Logs appear in Mule's
 * standard log output with full context.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {
 *       "id": "ORD-001",
 *       "amount": 150.0
 *     },
 *     {
 *       "id": "ORD-002",
 *       "amount": -10.0
 *     },
 *     {
 *       "id": "ORD-003",
 *       "amount": 5000.0
 *     }
 *   ],
 *   "threshold": 1000
 * }
 *
 * Output (application/json):
 * {
 * "processed": 3,
 * "flagged": [
 * {"id": "ORD-002", "reason": "negative_amount"},
 * {"id": "ORD-003", "reason": "above_threshold"}
 * ]
 * }
 */
%dw 2.0
output application/json
var validated = payload.orders map (order) -> do {
  var level = if (order.amount < 0) "WARN" else if (order.amount > payload.threshold) "WARN" else "INFO"
  var msg = if (order.amount < 0) "Negative amount on $(order.id)" else if (order.amount > payload.threshold) "Above threshold on $(order.id)" else "Processing order $(order.id)"
  ---
  if (order.amount < 0) {id: order.id, reason: "negative_amount", flagged: true, log: {level: level, message: msg}}
  else if (order.amount > payload.threshold) {id: order.id, reason: "above_threshold", flagged: true, log: {level: level, message: msg}}
  else {id: order.id, flagged: false, log: {level: level, message: msg}}
}
---
{processed: sizeOf(validated), flagged: validated filter $.flagged map ({id: $.id, reason: $.reason}), logs: validated map $.log}
