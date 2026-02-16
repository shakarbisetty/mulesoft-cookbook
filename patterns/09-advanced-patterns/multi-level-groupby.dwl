/**
 * Pattern: Multi-Level GroupBy
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Group data by multiple levels to create hierarchical structures.
 * Use when building tree-like reports, nested category views, or multi-level
 * aggregations — e.g., orders grouped by region, then by customer, then by
 * product category.
 *
 * Input (application/json):
 * [
 *   {"region": "North America", "country": "USA", "product": "Laptop", "revenue": 45000},
 *   {"region": "North America", "country": "USA", "product": "Monitor", "revenue": 12000},
 *   {"region": "North America", "country": "Canada", "product": "Laptop", "revenue": 8000},
 *   {"region": "Europe", "country": "UK", "product": "Laptop", "revenue": 22000},
 *   {"region": "Europe", "country": "UK", "product": "Keyboard", "revenue": 3500},
 *   {"region": "Europe", "country": "Germany", "product": "Monitor", "revenue": 15000},
 *   {"region": "Europe", "country": "Germany", "product": "Laptop", "revenue": 28000},
 *   {"region": "North America", "country": "USA", "product": "Keyboard", "revenue": 5500}
 * ]
 *
 * Output (application/json):
 * {
 *   "North America": {
 *     "USA": {
 *       "Laptop": {"totalRevenue": 45000, "count": 1},
 *       "Monitor": {"totalRevenue": 12000, "count": 1},
 *       "Keyboard": {"totalRevenue": 5500, "count": 1}
 *     },
 *     "Canada": {
 *       "Laptop": {"totalRevenue": 8000, "count": 1}
 *     }
 *   },
 *   "Europe": {
 *     "UK": {
 *       "Laptop": {"totalRevenue": 22000, "count": 1},
 *       "Keyboard": {"totalRevenue": 3500, "count": 1}
 *     },
 *     "Germany": {
 *       "Monitor": {"totalRevenue": 15000, "count": 1},
 *       "Laptop": {"totalRevenue": 28000, "count": 1}
 *     }
 *   }
 * }
 */
%dw 2.0
output application/json
---
payload groupBy $.region mapObject (regionItems, region) -> {
    (region): regionItems groupBy $.country mapObject (countryItems, country) -> {
        (country): countryItems groupBy $.product mapObject (productItems, product) -> {
            (product): {
                totalRevenue: sum(productItems.revenue),
                count: sizeOf(productItems)
            }
        }
    }
}

// Alternative 1 — two-level groupBy with summary:
// payload groupBy $.region mapObject (items, region) -> {
//     (region): {
//         totalRevenue: sum(items.revenue),
//         countries: sizeOf(items distinctBy $.country),
//         breakdown: items groupBy $.country
//     }
// }

// Alternative 2 — generic multi-level groupBy function:
// fun multiGroupBy(data: Array, keys: Array<String>): Any =
//     if (isEmpty(keys)) data
//     else data groupBy $[keys[0]] mapObject (items, group) ->
//         {(group): multiGroupBy(items, keys[1 to -1] default [])}
// ---
// multiGroupBy(payload, ["region", "country", "product"])

// Alternative 3 — flatten back to summary rows:
// payload groupBy $.region mapObject (items, region) -> {
//     (region): sum(items.revenue)
// }
