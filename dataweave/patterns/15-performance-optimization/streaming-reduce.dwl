/**
 * Pattern: Streaming with Reduce
 * Category: Performance & Optimization
 * Difficulty: Advanced
 *
 * Description: Use reduce to process large datasets in a single pass
 * without buffering. Compute aggregations (sum, count, min, max, running
 * totals) while streaming through records.
 *
 * Input (application/json):
 * [
 *   { "date": "2026-01-15", "product": "Widget", "region": "West", "amount": 1500, "units": 50 },
 *   { "date": "2026-01-16", "product": "Gadget", "region": "East", "amount": 2300, "units": 30 },
 *   { "date": "2026-01-16", "product": "Widget", "region": "West", "amount": 800, "units": 25 },
 *   { "date": "2026-01-17", "product": "Widget", "region": "East", "amount": 3100, "units": 100 },
 *   { "date": "2026-01-17", "product": "Gadget", "region": "West", "amount": 950, "units": 15 }
 * ]
 *
 * Output (application/json):
 * {
 *   "totalRevenue": 8650,
 *   "totalUnits": 220,
 *   "recordCount": 5,
 *   "avgOrderValue": 1730,
 *   "maxOrder": { "amount": 3100, "product": "Widget", "region": "East" },
 *   "revenueByProduct": { "Widget": 5400, "Gadget": 3250 },
 *   "revenueByRegion": { "West": 3250, "East": 5400 }
 * }
 */
%dw 2.0
output application/json

// Single-pass aggregation using reduce — processes one record at a time
var stats = payload reduce (item, acc = {
    totalRevenue: 0,
    totalUnits: 0,
    recordCount: 0,
    maxAmount: 0,
    maxOrder: {},
    byProduct: {},
    byRegion: {}
}) -> {
    totalRevenue: acc.totalRevenue + item.amount,
    totalUnits: acc.totalUnits + item.units,
    recordCount: acc.recordCount + 1,
    maxAmount: max([acc.maxAmount, item.amount]),
    maxOrder: if (item.amount > acc.maxAmount)
                  { amount: item.amount, product: item.product, region: item.region }
              else acc.maxOrder,
    byProduct: acc.byProduct ++ {
        (item.product): (acc.byProduct[item.product] default 0) + item.amount
    },
    byRegion: acc.byRegion ++ {
        (item.region): (acc.byRegion[item.region] default 0) + item.amount
    }
}
---
{
    totalRevenue: stats.totalRevenue,
    totalUnits: stats.totalUnits,
    recordCount: stats.recordCount,
    avgOrderValue: round(stats.totalRevenue / stats.recordCount),
    maxOrder: stats.maxOrder,
    revenueByProduct: stats.byProduct,
    revenueByRegion: stats.byRegion
}

// Why reduce instead of multiple passes?
// Bad:  sum(payload.amount) + (payload groupBy $.product) + max(payload.amount)
//       ^ This iterates the array 3 times
// Good: Single reduce iterates once — 3x faster on large datasets
