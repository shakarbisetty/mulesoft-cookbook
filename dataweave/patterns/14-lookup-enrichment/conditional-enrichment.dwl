/**
 * Pattern: Conditional Enrichment
 * Category: Lookup & Enrichment
 * Difficulty: Intermediate
 *
 * Description: Enrich records with additional fields based on business
 * rules. Apply different enrichment logic depending on record type,
 * status, or value thresholds.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     { "id": "ORD-001", "total": 1500, "channel": "web", "country": "US" },
 *     { "id": "ORD-002", "total": 250, "channel": "mobile", "country": "UK" },
 *     { "id": "ORD-003", "total": 5000, "channel": "web", "country": "US" },
 *     { "id": "ORD-004", "total": 75, "channel": "pos", "country": "CA" }
 *   ],
 *   "taxRates": { "US": 0.0875, "UK": 0.20, "CA": 0.13, "DE": 0.19 },
 *   "shippingRules": {
 *     "free_threshold": 500,
 *     "standard_rate": 9.99,
 *     "express_rate": 24.99
 *   }
 * }
 *
 * Output (application/json):
 * [
 *   {
 *     "id": "ORD-001",
 *     "total": 1500,
 *     "tier": "Gold",
 *     "tax": 131.25,
 *     "shipping": 0,
 *     "freeShipping": true,
 *     "grandTotal": 1631.25,
 *     "priority": "HIGH"
 *   },
 *   ...
 * ]
 */
%dw 2.0
output application/json

var taxRates = payload.taxRates
var shippingRules = payload.shippingRules

// Business rule: assign tier based on order total
fun assignTier(total: Number): String =
    if (total >= 5000) "Platinum"
    else if (total >= 1000) "Gold"
    else if (total >= 200) "Silver"
    else "Bronze"

// Business rule: determine priority based on total and channel
fun assignPriority(total: Number, channel: String): String =
    if (total >= 5000) "CRITICAL"
    else if (total >= 1000 or channel == "pos") "HIGH"
    else "STANDARD"

// Business rule: calculate shipping
fun calcShipping(total: Number): Number =
    if (total >= shippingRules.free_threshold) 0
    else shippingRules.standard_rate
---
payload.orders map (order) -> do {
    var tier = assignTier(order.total)
    var taxRate = taxRates[order.country] default 0
    var tax = order.total * taxRate
    var shipping = calcShipping(order.total)
    ---
    {
        id: order.id,
        total: order.total,
        channel: order.channel,
        country: order.country,
        tier: tier,
        tax: round(tax * 100) / 100,
        shipping: shipping,
        freeShipping: shipping == 0,
        grandTotal: round((order.total + tax + shipping) * 100) / 100,
        priority: assignPriority(order.total, order.channel)
    }
}
