/**
 * Pattern: JSON to CSV
 * Category: CSV Operations
 * Difficulty: Beginner
 *
 * Description: Convert a JSON array of objects to CSV format with headers.
 * Use when exporting data for spreadsheet consumption, generating bulk
 * upload files, creating reports, or feeding data to legacy systems
 * that only accept CSV input.
 *
 * Input (application/json):
 * [
 *   {"orderId": "ORD-1001", "customer": "Acme Corp", "product": "Laptop", "quantity": 5, "unitPrice": 1299.99, "orderDate": "2026-02-10"},
 *   {"orderId": "ORD-1002", "customer": "Globex Inc", "product": "Monitor", "quantity": 10, "unitPrice": 599.99, "orderDate": "2026-02-11"},
 *   {"orderId": "ORD-1003", "customer": "Acme Corp", "product": "Keyboard", "quantity": 20, "unitPrice": 149.99, "orderDate": "2026-02-12"}
 * ]
 *
 * Output (application/csv):
 * orderId,customer,product,quantity,unitPrice,total,orderDate
 * ORD-1001,Acme Corp,Laptop,5,1299.99,6499.95,2026-02-10
 * ORD-1002,Globex Inc,Monitor,10,599.99,5999.90,2026-02-11
 * ORD-1003,Acme Corp,Keyboard,20,149.99,2999.80,2026-02-12
 */
%dw 2.0
output application/csv
---
payload map (order) -> {
    orderId: order.orderId,
    customer: order.customer,
    product: order.product,
    quantity: order.quantity,
    unitPrice: order.unitPrice,
    total: order.quantity * order.unitPrice,
    orderDate: order.orderDate
}

// Alternative 1 — pass through (auto-converts if structure is flat):
// %dw 2.0
// output application/csv
// ---
// payload

// Alternative 2 — CSV with custom quoting:
// output application/csv quoteValues=true

// Alternative 3 — select specific columns only:
// payload map (order) -> {
//     orderId: order.orderId,
//     customer: order.customer,
//     total: order.quantity * order.unitPrice
// }

// Alternative 4 — CSV without headers:
// output application/csv header=false
