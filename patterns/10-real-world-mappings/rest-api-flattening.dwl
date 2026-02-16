/**
 * Pattern: REST API Response Flattening
 * Category: Real-World Mappings
 * Difficulty: Intermediate
 *
 * Description: Flatten a deeply nested REST API response into a flat table
 * structure suitable for database insertion, CSV export, or downstream
 * systems that require denormalized data. Common when consuming complex
 * API responses (e.g., Shopify orders, Salesforce queries, GitHub events).
 *
 * Input (application/json):
 * {
 *   "orders": [
 *     {
 *       "orderId": "ORD-1001",
 *       "orderDate": "2026-02-10",
 *       "customer": {
 *         "customerId": "C-100",
 *         "name": "Acme Corp",
 *         "address": {
 *           "city": "San Francisco",
 *           "state": "CA",
 *           "country": "US"
 *         }
 *       },
 *       "lineItems": [
 *         {"sku": "SKU-100", "product": "Laptop", "quantity": 2, "unitPrice": 1299.99},
 *         {"sku": "SKU-400", "product": "Mouse", "quantity": 5, "unitPrice": 29.99}
 *       ],
 *       "shipping": {"method": "Express", "cost": 25.00}
 *     },
 *     {
 *       "orderId": "ORD-1002",
 *       "orderDate": "2026-02-12",
 *       "customer": {
 *         "customerId": "C-200",
 *         "name": "Globex Inc",
 *         "address": {
 *           "city": "Austin",
 *           "state": "TX",
 *           "country": "US"
 *         }
 *       },
 *       "lineItems": [
 *         {"sku": "SKU-300", "product": "USB-C Hub", "quantity": 10, "unitPrice": 49.99}
 *       ],
 *       "shipping": {"method": "Standard", "cost": 0.00}
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {"orderId": "ORD-1001", "orderDate": "2026-02-10", "customerId": "C-100", "customerName": "Acme Corp", "city": "San Francisco", "state": "CA", "country": "US", "sku": "SKU-100", "product": "Laptop", "quantity": 2, "unitPrice": 1299.99, "lineTotal": 2599.98, "shippingMethod": "Express", "shippingCost": 25.00},
 *   {"orderId": "ORD-1001", "orderDate": "2026-02-10", "customerId": "C-100", "customerName": "Acme Corp", "city": "San Francisco", "state": "CA", "country": "US", "sku": "SKU-400", "product": "Mouse", "quantity": 5, "unitPrice": 29.99, "lineTotal": 149.95, "shippingMethod": "Express", "shippingCost": 25.00},
 *   {"orderId": "ORD-1002", "orderDate": "2026-02-12", "customerId": "C-200", "customerName": "Globex Inc", "city": "Austin", "state": "TX", "country": "US", "sku": "SKU-300", "product": "USB-C Hub", "quantity": 10, "unitPrice": 49.99, "lineTotal": 499.90, "shippingMethod": "Standard", "shippingCost": 0.00}
 * ]
 */
%dw 2.0
output application/json
---
payload.orders flatMap (order) ->
    order.lineItems map (item) -> {
        orderId: order.orderId,
        orderDate: order.orderDate,
        customerId: order.customer.customerId,
        customerName: order.customer.name,
        city: order.customer.address.city,
        state: order.customer.address.state,
        country: order.customer.address.country,
        sku: item.sku,
        product: item.product,
        quantity: item.quantity,
        unitPrice: item.unitPrice,
        lineTotal: item.quantity * item.unitPrice,
        shippingMethod: order.shipping.method,
        shippingCost: order.shipping.cost
    }

// Alternative 1 — flatten with selective fields only:
// payload.orders flatMap (order) ->
//     order.lineItems map (item) -> {
//         orderId: order.orderId,
//         sku: item.sku,
//         total: item.quantity * item.unitPrice
//     }

// Alternative 2 — output as CSV for database import:
// %dw 2.0
// output application/csv
// ---
// (same transformation as above)
