/**
 * Pattern: EDI to JSON
 * Category: Real-World Mappings
 * Difficulty: Advanced
 * Description: Transform parsed EDI (X12/EDIFACT) data into a clean JSON
 * structure. In MuleSoft, EDI is first parsed by the X12/EDIFACT connector
 * into a DataWeave-accessible object. This pattern shows how to map the
 * parsed EDI segments into business-friendly JSON. Uses an X12 850
 * (Purchase Order) as the example.
 *
 * Input (application/json):
 * {
 *   "poNumber": "PO-2026-4521",
 *   "poDate": "20260215",
 *   "buyer": {
 *     "name": "Acme Corp",
 *     "id": "ACME-001"
 *   },
 *   "seller": {
 *     "name": "Global Supplies",
 *     "id": "GSUP-500"
 *   },
 *   "lineItems": [
 *     {
 *       "line": 1,
 *       "sku": "SKU-100",
 *       "desc": "Keyboard",
 *       "qty": 50,
 *       "price": 89.99
 *     },
 *     {
 *       "line": 2,
 *       "sku": "SKU-400",
 *       "desc": "Mouse",
 *       "qty": 100,
 *       "price": 24.99
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "purchaseOrder": {
 * "poNumber": "PO-2026-4521",
 * "poDate": "2026-02-15",
 * "poType": "New Order",
 * "buyer": {"name": "Acme Corporation", "id": "ACME-001"},
 * "seller": {"name": "Global Supplies Ltd", "id": "GSUP-500"},
 * "lineItems": [
 * {"lineNumber": 1, "sku": "SKU-100", "description": "Mechanical Keyboard", "quantity": 50, "unit": "EA", "unitPrice": 149.99, "lineTotal": 7499.50},
 * {"lineNumber": 2, "sku": "SKU-400", "description": "Wireless Mouse", "quantity": 100, "unit": "EA", "unitPrice": 29.99, "lineTotal": 2999.00}
 * ],
 * "orderTotal": 10498.50
 * }
 * }
 */
%dw 2.0
output application/json
var dateStr = payload.poDate
---
{
  purchaseOrder: {
    poNumber: payload.poNumber,
    poDate: "$(dateStr[0 to 3])-$(dateStr[4 to 5])-$(dateStr[6 to 7])",
    buyer: payload.buyer,
    seller: payload.seller,
    lineItems: payload.lineItems map (item) -> ({
      lineNumber: item.line, sku: item.sku, description: item.desc, quantity: item.qty, unitPrice: item.price, lineTotal: item.qty * item.price
    }),
    orderTotal: payload.lineItems reduce (item, acc = 0) -> acc + (item.qty * item.price)
  }
}
