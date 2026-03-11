/**
 * Pattern: REST API Response Flattening
 * Category: Real-World Mappings
 * Difficulty: Intermediate
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
 *           "state": "CA"
 *         }
 *       },
 *       "lineItems": [
 *         {
 *           "sku": "SKU-A",
 *           "qty": 2,
 *           "price": 29.99
 *         },
 *         {
 *           "sku": "SKU-B",
 *           "qty": 1,
 *           "price": 49.99
 *         }
 *       ]
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * {"orderId": "ORD-1001", "orderDate": "2026-02-10", "customerId": "C-100", "customerName": "Acme Corp", "city": "San Francisco", "state": "CA", "country": "US", "sku": "SKU-100", "product": "Laptop", "quantity": 2, "unitPrice": 1299.99, "lineTotal": 2599.98, "shippingMethod": "Express", "shippingCost": 25.00},
 * {"orderId": "ORD-1001", "orderDate": "2026-02-10", "customerId": "C-100", "customerName": "Acme Corp", "city": "San Francisco", "state": "CA", "country": "US", "sku": "SKU-400", "product": "Mouse", "quantity": 5, "unitPrice": 29.99, "lineTotal": 149.95, "shippingMethod": "Express", "shippingCost": 25.00},
 * {"orderId": "ORD-1002", "orderDate": "2026-02-12", "customerId": "C-200", "customerName": "Globex Inc", "city": "Austin", "state": "TX", "country": "US", "sku": "SKU-300", "product": "USB-C Hub", "quantity": 10, "unitPrice": 49.99, "lineTotal": 499.90, "shippingMethod": "Standard", "shippingCost": 0.00}
 * ]
 */
%dw 2.0
output application/json
---
payload.orders flatMap (order) ->
    order.lineItems map (item) -> ({
        orderId: order.orderId,
        orderDate: order.orderDate,
        customerId: order.customer.customerId,
        customerName: order.customer.name,
        city: order.customer.address.city,
        sku: item.sku,
        qty: item.qty,
        price: item.price
    })
