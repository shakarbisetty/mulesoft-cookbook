/**
 * Pattern: Decimal Math for Financial Calculations
 * Category: Math & Precision
 * Difficulty: Intermediate
 * Since: DataWeave 2.10 (Mule 4.11+)
 *
 * Description: Use DataWeave's decimal math functions for exact arithmetic
 * in financial and monetary calculations. Standard floating-point arithmetic
 * produces rounding errors (0.1 + 0.2 = 0.30000000000000004). The decimal
 * functions in dw::util::Math guarantee exact results with configurable
 * rounding modes, essential for invoices, tax calculations, and ledger entries.
 *
 * Input (application/json):
 * {
 *   "invoice": {
 *     "number": "INV-2026-0042",
 *     "currency": "USD",
 *     "lines": [
 *       {"sku": "WDG-A", "description": "Widget Alpha", "unitPrice": 19.99, "quantity": 7, "taxRate": 0.0825},
 *       {"sku": "WDG-B", "description": "Widget Beta", "unitPrice": 0.10, "quantity": 100, "taxRate": 0.0825},
 *       {"sku": "SVC-C", "description": "Setup Fee", "unitPrice": 149.95, "quantity": 1, "taxRate": 0},
 *       {"sku": "DSC-1", "description": "Volume Discount", "unitPrice": -15.00, "quantity": 1, "taxRate": 0}
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
import decimalAdd, decimalSubtract, decimalMultiply, decimalDivide, decimalRound from dw::util::Math
output application/json

// --- Floating-point problem demonstration ---
// Standard:  0.1 + 0.2 = 0.30000000000000004  (WRONG)
// Decimal:   decimalAdd(0.1, 0.2) = 0.3        (CORRECT)

// Calculate each line with exact decimal arithmetic
var computedLines = payload.invoice.lines map (line) -> do {
    // Exact multiplication: unitPrice * quantity
    var subtotal = decimalMultiply(line.unitPrice, line.quantity)

    // Tax: round to 2 decimal places using HALF_UP (banker's standard)
    var tax = decimalRound(decimalMultiply(subtotal, line.taxRate), 2, "HALF_UP")

    // Line total: subtotal + tax
    var lineTotal = decimalAdd(subtotal, tax)
    ---
    {
        sku: line.sku,
        subtotal: subtotal,
        tax: tax,
        lineTotal: lineTotal
    }
}

// Sum all line totals for invoice subtotal
var invoiceSubtotal = computedLines reduce (line, acc = 0) ->
    decimalAdd(acc, line.subtotal)

// Calculate discount on subtotal
var discountAmount = decimalRound(
    decimalMultiply(invoiceSubtotal, decimalDivide(payload.invoice.discountPercent, 100)),
    2,
    "HALF_UP"
)

// Sum all tax amounts
var taxTotal = computedLines reduce (line, acc = 0) ->
    decimalAdd(acc, line.tax)

// Grand total: subtotal - discount + tax
var grandTotal = decimalAdd(decimalSubtract(invoiceSubtotal, discountAmount), taxTotal)
---
{
    invoiceNumber: payload.invoice.number,
    lines: computedLines map {
        sku: $.sku,
        subtotal: $.subtotal,
        tax: $.tax,
        lineTotal: $.lineTotal
    },
    subtotal: invoiceSubtotal,
    discountAmount: discountAmount,
    taxTotal: taxTotal,
    grandTotal: grandTotal,
    currency: payload.invoice.currency
}

// =============================================================================
// ROUNDING MODES — choose the right one for your domain
// =============================================================================
//
// decimalRound(2.5, 0, "HALF_UP")    = 3    (standard rounding — most common)
// decimalRound(2.5, 0, "HALF_EVEN")  = 2    (banker's rounding — minimizes bias)
// decimalRound(2.5, 0, "HALF_DOWN")  = 2    (round toward zero on tie)
// decimalRound(2.5, 0, "CEILING")    = 3    (always round up)
// decimalRound(2.5, 0, "FLOOR")      = 2    (always round down)
//
// For financial systems:
//   - US tax calculations: HALF_UP (IRS standard)
//   - EU banking: HALF_EVEN (reduces cumulative rounding bias)
//   - Payment processing: HALF_UP (consumer expectation)

// =============================================================================
// CURRENCY CONVERSION — exact cross-rate calculation
// =============================================================================
//
// import decimalDivide, decimalMultiply, decimalRound from dw::util::Math
//
// var usdAmount = 1000.00
// var exchangeRate = 0.9247   // USD to EUR
// var eurAmount = decimalRound(decimalMultiply(usdAmount, exchangeRate), 2, "HALF_EVEN")
// // Result: 924.70 (exact, no floating-point drift)
//
// // Inverse conversion with full precision
// var backToUsd = decimalRound(decimalDivide(eurAmount, exchangeRate), 2, "HALF_EVEN")
// // Result: 1000.00 (round-trip preserved)

// =============================================================================
// COMPOUND INTEREST — precise multi-period calculation
// =============================================================================
//
// import decimalPow, decimalAdd, decimalMultiply, decimalRound from dw::util::Math
//
// var principal = 10000.00
// var annualRate = 0.045   // 4.5% APR
// var periods = 12         // monthly compounding for 1 year
// var monthlyRate = decimalDivide(annualRate, 12)
// var futureValue = decimalRound(
//     decimalMultiply(principal, decimalPow(decimalAdd(1, monthlyRate), periods)),
//     2,
//     "HALF_EVEN"
// )
// // Result: 10459.29 (exact, no accumulated floating-point error)

// =============================================================================
// AVOIDING COMMON FLOATING-POINT TRAPS
// =============================================================================
//
// TRAP 1: Direct comparison
//   BAD:  (0.1 + 0.2) == 0.3                         // false!
//   GOOD: decimalAdd(0.1, 0.2) == 0.3                 // true
//
// TRAP 2: Accumulated errors in reduce
//   BAD:  [0.1, 0.1, 0.1] reduce (v, acc=0) -> acc + v   // 0.30000000000000004
//   GOOD: [0.1, 0.1, 0.1] reduce (v, acc=0) -> decimalAdd(acc, v)  // 0.3
//
// TRAP 3: Tax calculation order
//   BAD:  Round each line tax, then sum (can lose pennies)
//   OK:   Sum all pre-tax, compute tax on total, then round once
//   BEST: Round each line, sum, compare to total-level calculation,
//         apply penny adjustment to largest line item
