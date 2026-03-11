/**
 * Pattern: Reduce / Accumulate
 * Category: Array Manipulation
 * Difficulty: Advanced
 * Description: Reduce an array to a single accumulated value. The most powerful
 * array function in DataWeave — use it to compute totals, build objects from
 * arrays, concatenate strings, find min/max, or perform any aggregation that
 * map/filter cannot express on their own.
 *
 * Input (application/json):
 * {
 *   "invoiceId": "INV-2026-0042",
 *   "customer": "Acme Corp",
 *   "lineItems": [
 *     {
 *       "description": "Consulting - API Design",
 *       "quantity": 40,
 *       "unitPrice": 150.0
 *     },
 *     {
 *       "description": "Development - Mule Flows",
 *       "quantity": 80,
 *       "unitPrice": 175.0
 *     },
 *     {
 *       "description": "Testing - MUnit Suite",
 *       "quantity": 20,
 *       "unitPrice": 125.0
 *     },
 *     {
 *       "description": "Documentation",
 *       "quantity": 10,
 *       "unitPrice": 100.0
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "invoiceId": "INV-2026-0042",
 * "customer": "Acme Corp",
 * "totalHours": 150,
 * "subtotal": 23500.00,
 * "tax": 1762.50,
 * "total": 25262.50
 * }
 */
%dw 2.0
output application/json
var taxRate = 0.075
var totals = payload.lineItems reduce (item, acc = {hours: 0, amount: 0}) -> ({hours: acc.hours + item.quantity, amount: acc.amount + (item.quantity * item.unitPrice)})
---
{invoiceId: payload.invoiceId, customer: payload.customer, totalHours: totals.hours, subtotal: totals.amount, tax: totals.amount * taxRate, total: totals.amount + (totals.amount * taxRate)}
