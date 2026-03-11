/**
 * Pattern: Epoch Conversion
 * Category: Date/Time
 * Difficulty: Intermediate
 * Description: Convert between Unix epoch timestamps (seconds or milliseconds
 * since 1970-01-01) and human-readable dates. Many APIs, databases, and
 * messaging systems use epoch timestamps — Kafka, AWS, Unix systems, and
 * JavaScript all commonly use epoch-based time.
 *
 * Input (application/json):
 * {
 *   "epochSeconds": 1771200000,
 *   "epochMillis": 1771200000000,
 *   "isoDate": "2026-02-15T14:30:00Z",
 *   "events": [
 *     {
 *       "name": "User Login",
 *       "timestamp": 1771185600
 *     },
 *     {
 *       "name": "Order Placed",
 *       "timestamp": 1771189200
 *     },
 *     {
 *       "name": "Payment Confirmed",
 *       "timestamp": 1771200000
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "fromEpochSeconds": "2026-02-16T00:00:00Z",
 * "fromEpochMillis": "2026-02-16T00:00:00Z",
 * "toEpochSeconds": 1771165800,
 * "toEpochMillis": 1771165800000,
 * "events": [
 * {"name": "User Login", "time": "2026-02-15T20:00:00Z"},
 * {"name": "Order Placed", "time": "2026-02-15T21:00:00Z"},
 * {"name": "Payment Confirmed", "time": "2026-02-16T00:00:00Z"}
 * ]
 * }
 */
%dw 2.0
output application/json
---
{
  fromSeconds: (payload.epochSeconds * 1000) as DateTime as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
  fromMillis: payload.epochMillis as DateTime as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
  toEpoch: (payload.isoDate as DateTime) as Number,
  events: payload.events map (e) -> ({
    name: e.name,
    time: (e.timestamp * 1000) as DateTime as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"}
  })
}
