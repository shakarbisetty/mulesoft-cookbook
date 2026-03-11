/**
 * Pattern: String to Date Conversion
 * Category: Type Coercion
 * Difficulty: Intermediate
 * Description: Parse date strings into proper Date/DateTime/LocalDateTime types
 * using format patterns. Essential when ingesting dates from APIs, databases,
 * or files that represent dates as strings in various formats (ISO 8601,
 * US format, European format, custom enterprise formats).
 *
 * Input (application/json):
 * {
 *   "isoDate": "2025-03-15",
 *   "usFormat": "03/15/2025",
 *   "europeanFormat": "15.03.2025",
 *   "customFormat": "15-Mar-2025 02:30 PM",
 *   "sapFormat": "20250315",
 *   "epochMillis": "1710460800000"
 * }
 *
 * Output (application/json):
 * {
 * "fromISO": "2026-02-15",
 * "fromISODateTime": "2026-02-15T14:30:00Z",
 * "fromUS": "2026-02-15",
 * "fromEuropean": "2026-02-15",
 * "fromCustom": "2026-02-15T14:30:00",
 * "fromSAP": "2026-02-15",
 * "allAsISO": "2026-02-15T14:30:00Z"
 * }
 */
%dw 2.0
output application/json
---
{fromISO: payload.isoDate as Date, fromUS: payload.usFormat as Date {format: "MM/dd/yyyy"}, fromEuropean: payload.europeanFormat as Date {format: "dd.MM.yyyy"}, fromSAP: payload.sapFormat as Date {format: "yyyyMMdd"}}
