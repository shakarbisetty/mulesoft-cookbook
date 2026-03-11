/**
 * Pattern: Date Arithmetic
 * Category: Date/Time
 * Difficulty: Intermediate
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
 * "deliveryDate": "2026-02-22",
 * "invoiceDueDate": "2026-03-17",
 * "warrantyExpiry": "2027-02-15",
 * "slaDeadline": "2026-02-15T18:30:00Z",
 * "nextBillingDate": "2026-02-01",
 * "trialEndDate": "2026-01-31",
 * "daysBetween": 45,
 * "yesterday": "2026-02-14",
 * "lastMonth": "2026-01-15"
 * }
 */
%dw 2.0
output application/json
var d = payload.orderDate as Date
var dt = payload.orderTime as DateTime
var sub = payload.subscriptionStart as Date
---
{
  deliveryDate: (d + |P7D|) as String {format: "yyyy-MM-dd"},
  invoiceDue: (d + |P30D|) as String {format: "yyyy-MM-dd"},
  warrantyExpiry: (d + |P1Y|) as String {format: "yyyy-MM-dd"},
  slaDeadline: (dt + |PT4H|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
  nextBilling: (sub + |P1M|) as String {format: "yyyy-MM-dd"},
  trialEnd: (sub + ("P$(payload.trialDays)D" as Period)) as String {format: "yyyy-MM-dd"}
}
