/**
 * Pattern: DW 2.10 Logging Functions
 * Category: Observability
 * Difficulty: Beginner
 *
 * Description: Validate customer records with inline log metadata for each
 * decision. Each record carries a log object with level and message, creating
 * an audit trail directly in the transform output.
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
 *   },
 *   "logs": [
 *     {"level": "DEBUG", "message": "OK: gold tier"},
 *     {"level": "WARN", "message": "Negative balance: -200"},
 *     {"level": "DEBUG", "message": "OK: bronze tier"},
 *     {"level": "WARN", "message": "Exceeds limit: 75000 > 50000"}
 *   ]
 * }
 */
%dw 2.0
output application/json
var results = payload.customers map (customer) -> do {
  var level = if (customer.balance < 0) "WARN" else if (customer.balance > payload.creditLimit) "WARN" else "DEBUG"
  var msg = if (customer.balance < 0) "Negative balance: $(customer.balance)" else if (customer.balance > payload.creditLimit) "Exceeds limit: $(customer.balance) > $(payload.creditLimit)" else "OK: $(customer.tier) tier"
  ---
  {id: customer.id, name: customer.name, tier: customer.tier, flagged: level == "WARN", log: {level: level, message: msg}}
}
var alerts = results filter $.flagged
---
{
  totalProcessed: sizeOf(results),
  alerts: alerts map ({id: $.id, issue: $.log.message, balance: $.log.message}),
  summary: results groupBy $.tier mapObject (items, tier) -> ({(tier): sizeOf(items)}),
  logs: results map $.log
}
