/**
 * Pattern: Group By Field
 * Category: Array Manipulation
 * Difficulty: Intermediate
 *
 * Description: Group an array of objects by a shared field value. Transforms a
 * flat list into an object where each key is a distinct field value and its
 * value is an array of matching items. Essential for building summaries,
 * categorized views, and reporting data.
 *
 * Input (application/json):
 * [
 *   {"orderId": "ORD-1001", "product": "Laptop", "category": "Electronics", "amount": 1299.99},
 *   {"orderId": "ORD-1002", "product": "Headphones", "category": "Electronics", "amount": 199.95},
 *   {"orderId": "ORD-1003", "product": "Desk Chair", "category": "Furniture", "amount": 449.00},
 *   {"orderId": "ORD-1004", "product": "Monitor", "category": "Electronics", "amount": 599.99},
 *   {"orderId": "ORD-1005", "product": "Standing Desk", "category": "Furniture", "amount": 799.00},
 *   {"orderId": "ORD-1006", "product": "Notebook", "category": "Stationery", "amount": 12.50}
 * ]
 *
 * Output (application/json):
 * {
 *   "Electronics": [
 *     {"orderId": "ORD-1001", "product": "Laptop", "category": "Electronics", "amount": 1299.99},
 *     {"orderId": "ORD-1002", "product": "Headphones", "category": "Electronics", "amount": 199.95},
 *     {"orderId": "ORD-1004", "product": "Monitor", "category": "Electronics", "amount": 599.99}
 *   ],
 *   "Furniture": [
 *     {"orderId": "ORD-1003", "product": "Desk Chair", "category": "Furniture", "amount": 449.00},
 *     {"orderId": "ORD-1005", "product": "Standing Desk", "category": "Furniture", "amount": 799.00}
 *   ],
 *   "Stationery": [
 *     {"orderId": "ORD-1006", "product": "Notebook", "category": "Stationery", "amount": 12.50}
 *   ]
 * }
 */
%dw 2.0
output application/json
---
payload groupBy (order) -> order.category

// Alternative 1 — shorthand:
// payload groupBy $.category

// Alternative 2 — group by computed value (e.g., price range):
// payload groupBy (order) ->
//     if (order.amount > 500) "Premium"
//     else if (order.amount > 100) "Standard"
//     else "Budget"

// Alternative 3 — group then transform each group:
// payload groupBy $.category
//     mapObject (items, category) -> {
//         (category): {
//             count: sizeOf(items),
//             total: sum(items.amount),
//             items: items
//         }
//     }
