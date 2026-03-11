/**
 * Pattern: Date Formatting
 * Category: Date/Time
 * Difficulty: Beginner
 * Description: Format dates and datetimes into various string representations.
 * Different systems require different date formats — ISO 8601, US, European,
 * SAP, Oracle, human-readable, and more. This pattern covers the most common
 * formatting needs.
 *
 * Input (application/json):
 * {
 *   "orderDate": "2026-02-15T14:30:45Z",
 *   "invoiceDate": "2026-02-15"
 * }
 *
 * Output (application/json):
 * {
 * "iso8601": "2026-02-15T14:30:45Z",
 * "usFormat": "02/15/2026",
 * "europeanFormat": "15.02.2026",
 * "longFormat": "February 15, 2026",
 * "shortFormat": "Feb 15, 2026",
 * "sapFormat": "20260215",
 * "timeOnly": "14:30:45",
 * "time12h": "02:30 PM",
 * "dayOfWeek": "Sunday",
 * "yearMonth": "2026-02",
 * "custom": "15-FEB-2026"
 * }
 */
%dw 2.0
output application/json
var dt = payload.orderDate as DateTime
var d = payload.invoiceDate as Date
---
{
  iso8601: dt as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
  usFormat: d as String {format: "MM/dd/yyyy"},
  europeanFormat: d as String {format: "dd.MM.yyyy"},
  longFormat: d as String {format: "MMMM dd, yyyy"},
  sapFormat: d as String {format: "yyyyMMdd"},
  dayOfWeek: dt as String {format: "EEEE"}
}
