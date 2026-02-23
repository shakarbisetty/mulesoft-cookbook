/**
 * Pattern: Decimal Precision Arithmetic
 * Category: Math & Precision
 * Difficulty: Intermediate
 *
 * Description: Use DataWeave 2.10's decimal math functions to avoid
 * floating-point errors in financial calculations. Standard arithmetic
 * gives 0.1 + 0.2 = 0.30000000000000004. Decimal functions give exact results.
 *
 * Input (application/json):
 * {
 *   "lineItems": [
 *     {"product": "Widget A", "price": 19.99, "quantity": 3, "taxRate": 0.0825},
 *     {"product": "Widget B", "price": 49.95, "quantity": 1, "taxRate": 0.0825},
 *     {"product": "Discount", "price": -5.50, "quantity": 1, "taxRate": 0}
 *   ],
 *   "currency": "USD"
 * }
 *
 * Output (application/json):
 * {
 *   "lineItems": [
 *     {"product": "Widget A", "subtotal": 59.97, "tax": 4.95, "total": 64.92},
 *     {"product": "Widget B", "subtotal": 49.95, "tax": 4.12, "total": 54.07},
 *     {"product": "Discount", "subtotal": -5.50, "tax": 0.00, "total": -5.50}
 *   ],
 *   "grandTotal": 113.49,
 *   "currency": "USD"
 * }
 */
%dw 2.0
import decimalAdd, decimalMultiply, decimalSubtract, decimalRound from dw::util::Math
output application/json

var computed = payload.lineItems map (item) -> do {
    var subtotal = decimalMultiply(item.price, item.quantity)
    var tax = decimalRound(decimalMultiply(subtotal, item.taxRate), 2)
    var total = decimalAdd(subtotal, tax)
    ---
    {
        product: item.product,
        subtotal: subtotal,
        tax: tax,
        total: total
    }
}
---
{
    lineItems: computed,
    grandTotal: computed reduce (item, acc = 0) -> decimalAdd(acc, item.total),
    currency: payload.currency
}

// Alternative 1 — currency conversion with precise division:
// import decimalDivide from dw::util::Math
// var usdToEur = decimalDivide(amount, 1.0847)

// Alternative 2 — compound interest with decimalPow:
// import decimalPow, decimalAdd, decimalMultiply from dw::util::Math
// var futureValue = decimalMultiply(principal, decimalPow(decimalAdd(1, rate), periods))

// Alternative 3 — precise percentage calculation:
// var pct = decimalRound(decimalMultiply(decimalDivide(part, whole), 100), 2)
