/**
 * Pattern: String to Date Conversion
 * Category: Type Coercion
 * Difficulty: Intermediate
 *
 * Description: Parse date strings into proper Date/DateTime/LocalDateTime types
 * using format patterns. Essential when ingesting dates from APIs, databases,
 * or files that represent dates as strings in various formats (ISO 8601,
 * US format, European format, custom enterprise formats).
 *
 * Input (application/json):
 * {
 *   "isoDate": "2026-02-15",
 *   "isoDateTime": "2026-02-15T14:30:00Z",
 *   "usFormat": "02/15/2026",
 *   "europeanFormat": "15.02.2026",
 *   "customFormat": "15-FEB-2026 02:30 PM",
 *   "sapFormat": "20260215"
 * }
 *
 * Output (application/json):
 * {
 *   "fromISO": "2026-02-15",
 *   "fromISODateTime": "2026-02-15T14:30:00Z",
 *   "fromUS": "2026-02-15",
 *   "fromEuropean": "2026-02-15",
 *   "fromCustom": "2026-02-15T14:30:00",
 *   "fromSAP": "2026-02-15",
 *   "allAsISO": "2026-02-15T14:30:00Z"
 * }
 */
%dw 2.0
output application/json
---
{
    fromISO: payload.isoDate as Date,
    fromISODateTime: payload.isoDateTime as DateTime,
    fromUS: payload.usFormat as Date {format: "MM/dd/yyyy"},
    fromEuropean: payload.europeanFormat as Date {format: "dd.MM.yyyy"},
    fromCustom: payload.customFormat as LocalDateTime {format: "dd-MMM-yyyy hh:mm a"},
    fromSAP: payload.sapFormat as Date {format: "yyyyMMdd"},
    allAsISO: payload.isoDateTime as DateTime
}

// Alternative 1 — coerce with default for unparseable dates:
// (payload.maybeDate as Date {format: "yyyy-MM-dd"}) default "1970-01-01" as Date

// Alternative 2 — parse and reformat in one step:
// payload.usFormat as Date {format: "MM/dd/yyyy"} as String {format: "yyyy-MM-dd"}
// Output: "2026-02-15"

// Alternative 3 — handle multiple possible formats with try:
// do {
//     var d = try(() -> payload.input as Date {format: "yyyy-MM-dd"})
//     var d2 = try(() -> payload.input as Date {format: "MM/dd/yyyy"})
//     ---
//     if (d.success) d.result
//     else if (d2.success) d2.result
//     else null
// }
