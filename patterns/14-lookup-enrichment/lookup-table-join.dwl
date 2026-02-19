/**
 * Pattern: Lookup Table Join
 * Category: Lookup & Enrichment
 * Difficulty: Intermediate
 *
 * Description: Join a primary dataset with a reference/lookup table,
 * similar to a SQL LEFT JOIN. Common for enriching order data with
 * product details, customer records with region info, etc.
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     { "orderId": "ORD-001", "productCode": "PROD-A", "qty": 3, "customerId": "C100" },
 *     { "orderId": "ORD-002", "productCode": "PROD-B", "qty": 1, "customerId": "C200" },
 *     { "orderId": "ORD-003", "productCode": "PROD-A", "qty": 5, "customerId": "C100" },
 *     { "orderId": "ORD-004", "productCode": "PROD-C", "qty": 2, "customerId": "C300" }
 *   ],
 *   "products": [
 *     { "code": "PROD-A", "name": "Widget Pro", "price": 29.99, "category": "Hardware" },
 *     { "code": "PROD-B", "name": "Gadget Plus", "price": 49.99, "category": "Electronics" },
 *     { "code": "PROD-C", "name": "Thingamajig", "price": 14.99, "category": "Accessories" }
 *   ],
 *   "customers": [
 *     { "id": "C100", "name": "Acme Corp", "region": "West" },
 *     { "id": "C200", "name": "Globex Inc", "region": "East" },
 *     { "id": "C300", "name": "Initech", "region": "Central" }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {
 *     "orderId": "ORD-001",
 *     "product": { "name": "Widget Pro", "price": 29.99, "category": "Hardware" },
 *     "customer": { "name": "Acme Corp", "region": "West" },
 *     "qty": 3,
 *     "lineTotal": 89.97
 *   },
 *   ...
 * ]
 */
%dw 2.0
output application/json

// Pre-index lookup tables by key for O(1) access
var productIndex = payload.products indexBy $.code
var customerIndex = payload.customers indexBy $.id
---
payload.orders map (order) -> do {
    var product = productIndex[order.productCode]
    var customer = customerIndex[order.customerId]
    ---
    {
        orderId: order.orderId,
        product: {
            name: product.name default "Unknown Product",
            price: product.price default 0,
            category: product.category default "N/A"
        },
        customer: {
            name: customer.name default "Unknown Customer",
            region: customer.region default "N/A"
        },
        qty: order.qty,
        lineTotal: (product.price default 0) * order.qty
    }
}

// Alternative — using dw::core::Arrays join (SQL-style):
// import join from dw::core::Arrays
// join(payload.orders, payload.products,
//     (o) -> o.productCode, (p) -> p.code)
// map (pair) -> { order: pair.l, product: pair.r }
