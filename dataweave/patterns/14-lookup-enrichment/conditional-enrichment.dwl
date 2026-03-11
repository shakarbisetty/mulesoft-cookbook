/**
 * Pattern: Conditional Enrichment
 * Category: Lookup & Enrichment
 * Difficulty: Intermediate
 * Description: Enrich records with additional fields based on business
 * rules. Apply different enrichment logic depending on record type,
 * status, or value thresholds.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {
 *       "id": "O1",
 *       "total": 5200,
 *       "country": "US"
 *     },
 *     {
 *       "id": "O2",
 *       "total": 450,
 *       "country": "UK"
 *     },
 *     {
 *       "id": "O3",
 *       "total": 80,
 *       "country": "US"
 *     }
 *   ],
 *   "taxRates": {
 *     "US": 0.08,
 *     "UK": 0.2
 *   },
 *   "shippingRules": {
 *     "free_threshold": 500,
 *     "standard_rate": 12.99
 *   }
 * }
 *
 * Output (application/json):
 * [
 * {
 * "id": "ORD-001",
 * "total": 1500,
 * "tier": "Gold",
 * "tax": 131.25,
 * "shipping": 0,
 * "freeShipping": true,
 * "grandTotal": 1631.25,
 * "priority": "HIGH"
 * },
 * ...
 * ]
 */
%dw 2.0
output application/json
var taxRates = payload.taxRates
var shippingRules = payload.shippingRules
fun assignTier(total: Number): String =
  if (total >= 5000) "Platinum" else if (total >= 1000) "Gold" else if (total >= 200) "Silver" else "Bronze"
fun calcShipping(total: Number): Number =
  if (total >= shippingRules.free_threshold) 0 else shippingRules.standard_rate
---
payload.orders map (order) -> do {
  var tax = round(order.total * (taxRates[order.country] default 0) * 100) / 100
  ---
  {id: order.id, total: order.total, tier: assignTier(order.total), tax: tax, shipping: calcShipping(order.total)}
}
