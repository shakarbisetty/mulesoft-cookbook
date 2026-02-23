/**
 * Pattern: Date Formatting
 * Category: Date/Time
 * Difficulty: Beginner
 *
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
 *   "iso8601": "2026-02-15T14:30:45Z",
 *   "usFormat": "02/15/2026",
 *   "europeanFormat": "15.02.2026",
 *   "longFormat": "February 15, 2026",
 *   "shortFormat": "Feb 15, 2026",
 *   "sapFormat": "20260215",
 *   "timeOnly": "14:30:45",
 *   "time12h": "02:30 PM",
 *   "dayOfWeek": "Sunday",
 *   "yearMonth": "2026-02",
 *   "custom": "15-FEB-2026"
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
    shortFormat: d as String {format: "MMM dd, yyyy"},
    sapFormat: d as String {format: "yyyyMMdd"},
    timeOnly: dt as String {format: "HH:mm:ss"},
    time12h: dt as String {format: "hh:mm a"},
    dayOfWeek: d as String {format: "EEEE"},
    yearMonth: d as String {format: "yyyy-MM"},
    custom: d as String {format: "dd-MMM-yyyy"} replace /(\w{3})/ with upper($[1])
}

// Common format pattern reference:
// yyyy  = 4-digit year (2026)
// MM    = 2-digit month (02)
// dd    = 2-digit day (15)
// HH    = 24-hour (14)
// hh    = 12-hour (02)
// mm    = minutes (30)
// ss    = seconds (45)
// a     = AM/PM
// EEEE  = full day name (Sunday)
// EEE   = short day name (Sun)
// MMMM  = full month name (February)
// MMM   = short month name (Feb)
// XXX   = timezone offset (+00:00)
// Z     = timezone offset (+0000)
