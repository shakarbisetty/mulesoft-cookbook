/**
 * Pattern: Lookup Table Join
 * Category: Lookup & Enrichment
 * Difficulty: Intermediate
 * Description: Join a primary dataset with a reference/lookup table,
 * similar to a SQL LEFT JOIN. Common for enriching order data with
 * product details, customer records with region info, etc.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {
 *       "orderId": "O1",
 *       "productCode": "P100",
 *       "customerId": "C1",
 *       "qty": 2
 *     },
 *     {
 *       "orderId": "O2",
 *       "productCode": "P200",
 *       "customerId": "C2",
 *       "qty": 5
 *     },
 *     {
 *       "orderId": "O3",
 *       "productCode": "P100",
 *       "customerId": "C1",
 *       "qty": 1
 *     }
 *   ],
 *   "products": [
 *     {
 *       "code": "P100",
 *       "name": "Widget",
 *       "price": 25
 *     },
 *     {
 *       "code": "P200",
 *       "name": "Gadget",
 *       "price": 50
 *     }
 *   ],
 *   "customers": [
 *     {
 *       "id": "C1",
 *       "name": "Acme Corp"
 *     },
 *     {
 *       "id": "C2",
 *       "name": "Beta Inc"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * {
 * "orderId": "ORD-001",
 * "product": { "name": "Widget Pro", "price": 29.99, "category": "Hardware" },
 * "customer": { "name": "Acme Corp", "region": "West" },
 * "qty": 3,
 * "lineTotal": 89.97
 * },
 * ...
 * ]
 */
%dw 2.0
output application/json
var productIndex = payload.products indexBy $.code
var customerIndex = payload.customers indexBy $.id
---
payload.orders map (order) -> do {
    var product = productIndex[order.productCode]
    var customer = customerIndex[order.customerId]
    ---
    ({ orderId: order.orderId, product: product.name default "Unknown", customer: customer.name default "Unknown", qty: order.qty, lineTotal: (product.price default 0) * order.qty })
}
