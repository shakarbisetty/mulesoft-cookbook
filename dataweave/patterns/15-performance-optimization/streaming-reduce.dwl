/**
 * Pattern: Streaming with Reduce
 * Category: Performance & Optimization
 * Difficulty: Advanced
 * Description: Use reduce to process large datasets in a single pass
 * without buffering. Compute aggregations (sum, count, min, max, running
 * totals) while streaming through records.
 *
 * Input (application/json):
 * [
 *   {
 *     "product": "Widget",
 *     "amount": 500,
 *     "units": 20
 *   },
 *   {
 *     "product": "Gadget",
 *     "amount": 1200,
 *     "units": 15
 *   },
 *   {
 *     "product": "Widget",
 *     "amount": 800,
 *     "units": 30
 *   },
 *   {
 *     "product": "Gadget",
 *     "amount": 600,
 *     "units": 10
 *   },
 *   {
 *     "product": "Gizmo",
 *     "amount": 950,
 *     "units": 25
 *   }
 * ]
 *
 * Output (application/json):
 * {
 * "totalRevenue": 8650,
 * "totalUnits": 220,
 * "recordCount": 5,
 * "avgOrderValue": 1730,
 * "maxOrder": { "amount": 3100, "product": "Widget", "region": "East" },
 * "revenueByProduct": { "Widget": 5400, "Gadget": 3250 },
 * "revenueByRegion": { "West": 3250, "East": 5400 }
 * }
 */
%dw 2.0
output application/json
var stats = payload reduce (item, acc = {totalRevenue: 0, totalUnits: 0, count: 0, maxAmount: 0, maxOrder: {}, byProduct: {}}) -> ({
  totalRevenue: acc.totalRevenue + item.amount,
  totalUnits: acc.totalUnits + item.units,
  count: acc.count + 1,
  maxAmount: if (item.amount > acc.maxAmount) item.amount else acc.maxAmount,
  maxOrder: if (item.amount > acc.maxAmount) {amount: item.amount, product: item.product} else acc.maxOrder,
  byProduct: acc.byProduct ++ {(item.product): (acc.byProduct[item.product] default 0) + item.amount}})
---
{totalRevenue: stats.totalRevenue, totalUnits: stats.totalUnits, avgOrderValue: round(stats.totalRevenue / stats.count), maxOrder: stats.maxOrder, revenueByProduct: stats.byProduct}
