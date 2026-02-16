/**
 * Pattern: Date Arithmetic
 * Category: Date/Time
 * Difficulty: Intermediate
 *
 * Description: Add or subtract time periods from dates using Period and
 * Duration literals. Use for calculating due dates, SLA deadlines, expiry
 * dates, billing periods, and scheduling future events.
 *
 * Input (application/json):
 * {
 *   "orderDate": "2026-02-15",
 *   "orderTime": "2026-02-15T14:30:00Z",
 *   "subscriptionStart": "2026-01-01",
 *   "trialDays": 30
 * }
 *
 * Output (application/json):
 * {
 *   "deliveryDate": "2026-02-22",
 *   "invoiceDueDate": "2026-03-17",
 *   "warrantyExpiry": "2027-02-15",
 *   "slaDeadline": "2026-02-15T18:30:00Z",
 *   "nextBillingDate": "2026-02-01",
 *   "trialEndDate": "2026-01-31",
 *   "daysBetween": 45,
 *   "yesterday": "2026-02-14",
 *   "lastMonth": "2026-01-15"
 * }
 */
%dw 2.0
output application/json
var orderDate = payload.orderDate as Date
var orderTime = payload.orderTime as DateTime
var subStart = payload.subscriptionStart as Date
---
{
    deliveryDate: orderDate + |P7D|,
    invoiceDueDate: orderDate + |P30D|,
    warrantyExpiry: orderDate + |P1Y|,
    slaDeadline: orderTime + |PT4H|,
    nextBillingDate: subStart + |P1M|,
    trialEndDate: subStart + |P$(payload.trialDays)D|,
    daysBetween: (orderDate - subStart).days,
    yesterday: orderDate - |P1D|,
    lastMonth: orderDate - |P1M|
}

// Period literals reference:
// |P1D|    = 1 day
// |P7D|    = 7 days
// |P30D|   = 30 days
// |P1M|    = 1 month
// |P1Y|    = 1 year
// |P1Y6M|  = 1 year 6 months
// |PT1H|   = 1 hour
// |PT30M|  = 30 minutes
// |PT1H30M| = 1 hour 30 minutes

// Alternative 1 — calculate age:
// var birthDate = "1990-05-20" as Date
// var today = now() as Date
// ---
// (today - birthDate).years

// Alternative 2 — business days (skip weekends):
// fun addBusinessDays(start: Date, days: Number): Date =
//     if (days <= 0) start
//     else do {
//         var next = start + |P1D|
//         var dayOfWeek = next as String {format: "e"} as Number
//         ---
//         if (dayOfWeek >= 6) addBusinessDays(next, days)
//         else addBusinessDays(next, days - 1)
//     }
