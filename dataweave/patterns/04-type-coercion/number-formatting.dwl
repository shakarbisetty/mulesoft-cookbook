/**
 * Pattern: Number Formatting
 * Category: Type Coercion
 * Difficulty: Beginner
 * Description: Format numbers as strings with specific patterns — currency
 * display, percentage formatting, zero-padding, decimal precision, and
 * thousand separators. Use when building human-readable reports, invoices,
 * or API responses that require specific numeric representations.
 *
 * Input (application/json):
 * {
 *   "price": 1299.5,
 *   "taxRate": 0.0875,
 *   "quantity": 42,
 *   "largeNumber": 1234567.89,
 *   "percentage": 0.9534,
 *   "smallDecimal": 3.1
 * }
 *
 * Output (application/json):
 * {
 * "currency": "1,299.50",
 * "taxPercent": "8.75%",
 * "zeroPadded": "00042",
 * "withThousands": "1,234,567.89",
 * "percentDisplay": "95.34%",
 * "twoDecimals": "3.10",
 * "noDecimals": "1300",
 * "scientific": "1.23E6"
 * }
 */
%dw 2.0
output application/json
---
{
    currency: payload.price as String {format: "#,##0.00"},
    taxPercent: (payload.taxRate * 100) as String {format: "0.##"} ++ "%",
    zeroPadded: payload.quantity as String {format: "00000"},
    withThousands: payload.largeNumber as String {format: "#,##0.00"},
    percentDisplay: (payload.percentage * 100) as String {format: "0.00"} ++ "%",
    twoDecimals: payload.smallDecimal as String {format: "0.00"}
}
