/**
 * Pattern: String Padding
 * Category: String Operations
 * Difficulty: Intermediate
 * Description: Pad strings to a fixed width with a specified character. Common
 * when generating fixed-width flat files, formatting invoice numbers, aligning
 * columns for reports, or producing zero-padded IDs for systems that require
 * fixed-length fields (e.g., SAP, mainframes, EDI).
 *
 * Input (application/json):
 * {
 *   "invoices": [
 *     {
 *       "number": 42,
 *       "amount": 1299.5,
 *       "department": "ENG"
 *     },
 *     {
 *       "number": 1587,
 *       "amount": 85.0,
 *       "department": "MKT"
 *     },
 *     {
 *       "number": 7,
 *       "amount": 24500.75,
 *       "department": "FIN"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * {"invoiceId": "INV-00042", "amount": "   1299.50", "department": "ENG   "},
 * {"invoiceId": "INV-01587", "amount": "     85.00", "department": "MKT   "},
 * {"invoiceId": "INV-00007", "amount": "  24500.75", "department": "FIN   "}
 * ]
 */
%dw 2.0
output application/json
---
payload.invoices map (inv) -> ({
  invoiceId: "INV-" ++ padLeft(inv.number as String, 5, "0"),
  amount: padLeft(inv.amount as String {format: "0.00"}, 10),
  department: padRight(inv.department, 6)
})
