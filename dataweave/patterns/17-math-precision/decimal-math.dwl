/**
 * Pattern: Decimal Math for Financial Calculations
 * Category: Math & Precision
 * Difficulty: Intermediate
 *
 * Description: Calculate invoices with exact arithmetic to prevent penny drift.
 * Uses round-multiply-divide technique to lock tax and discount amounts to
 * exactly 2 decimal places on every line item.
 *
 * Input (application/json):
 * {
 *   "invoice": {
 *     "number": "INV-2026-0042",
 *     "currency": "USD",
 *     "lines": [
 *       {"sku": "WDG-A", "unitPrice": 19.99, "quantity": 7, "taxRate": 0.0825},
 *       {"sku": "WDG-B", "unitPrice": 0.10, "quantity": 100, "taxRate": 0.0825},
 *       {"sku": "SVC-C", "unitPrice": 149.95, "quantity": 1, "taxRate": 0},
 *       {"sku": "DSC-1", "unitPrice": -15.00, "quantity": 1, "taxRate": 0}
 *     ],
 *     "discountPercent": 5
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "invoiceNumber": "INV-2026-0042",
 *   "lines": [
 *     {"sku": "WDG-A", "subtotal": 139.93, "tax": 11.54, "lineTotal": 151.47},
 *     {"sku": "WDG-B", "subtotal": 10.00, "tax": 0.83, "lineTotal": 10.83},
 *     {"sku": "SVC-C", "subtotal": 149.95, "tax": 0.00, "lineTotal": 149.95},
 *     {"sku": "DSC-1", "subtotal": -15.00, "tax": 0.00, "lineTotal": -15.00}
 *   ],
 *   "subtotal": 284.88,
 *   "discountAmount": 14.24,
 *   "taxTotal": 12.37,
 *   "grandTotal": 283.01,
 *   "currency": "USD"
 * }
 */
%dw 2.0
output application/json
var computed = payload.invoice.lines map (line) -> do {
  var subtotal = line.unitPrice * line.quantity
  var tax = round(subtotal * line.taxRate * 100) / 100
  var lineTotal = subtotal + tax
  ---
  {sku: line.sku, subtotal: subtotal, tax: tax, lineTotal: lineTotal}
}
var invoiceSubtotal = computed reduce (item, acc = 0) -> acc + item.subtotal
var discountAmount = round(invoiceSubtotal * payload.invoice.discountPercent / 100 * 100) / 100
var taxTotal = computed reduce (item, acc = 0) -> acc + item.tax
---
{
  invoiceNumber: payload.invoice.number,
  lines: computed,
  subtotal: invoiceSubtotal,
  discountAmount: discountAmount,
  taxTotal: taxTotal,
  grandTotal: invoiceSubtotal - discountAmount + taxTotal,
  currency: payload.invoice.currency
}
