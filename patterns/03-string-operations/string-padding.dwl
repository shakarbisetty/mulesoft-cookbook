/**
 * Pattern: String Padding
 * Category: String Operations
 * Difficulty: Intermediate
 *
 * Description: Pad strings to a fixed width with a specified character. Common
 * when generating fixed-width flat files, formatting invoice numbers, aligning
 * columns for reports, or producing zero-padded IDs for systems that require
 * fixed-length fields (e.g., SAP, mainframes, EDI).
 *
 * Input (application/json):
 * {
 *   "invoices": [
 *     {"number": 42, "amount": 1299.5, "department": "ENG"},
 *     {"number": 1587, "amount": 85.0, "department": "MKT"},
 *     {"number": 7, "amount": 24500.75, "department": "FIN"}
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {"invoiceId": "INV-00042", "amount": "   1299.50", "department": "ENG   "},
 *   {"invoiceId": "INV-01587", "amount": "     85.00", "department": "MKT   "},
 *   {"invoiceId": "INV-00007", "amount": "  24500.75", "department": "FIN   "}
 * ]
 */
%dw 2.0
output application/json

fun padLeft(s: String, len: Number, char: String = " "): String =
    if (sizeOf(s) >= len) s
    else padLeft(char ++ s, len, char)

fun padRight(s: String, len: Number, char: String = " "): String =
    if (sizeOf(s) >= len) s
    else padRight(s ++ char, len, char)
---
payload.invoices map (inv) -> {
    invoiceId: "INV-" ++ padLeft(inv.number as String, 5, "0"),
    amount: padLeft(inv.amount as String {format: "0.00"}, 10),
    department: padRight(inv.department, 6)
}

// Alternative 1 — zero-pad with format string (numbers only):
// inv.number as String {format: "00000"}
// Output: "00042"

// Alternative 2 — left pad using repeat + substring:
// var s = inv.number as String
// var pad = ("00000" ++ s)
// ---
// pad[-5 to -1]

// Alternative 3 — right pad for fixed-width flat file record:
// padRight(inv.department, 10) ++ padLeft(inv.amount as String, 12, "0")
