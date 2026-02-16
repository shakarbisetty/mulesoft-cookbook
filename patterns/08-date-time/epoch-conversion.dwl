/**
 * Pattern: Epoch Conversion
 * Category: Date/Time
 * Difficulty: Intermediate
 *
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
 *     {"name": "User Login", "timestamp": 1771185600},
 *     {"name": "Order Placed", "timestamp": 1771189200},
 *     {"name": "Payment Confirmed", "timestamp": 1771200000}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "fromEpochSeconds": "2026-02-16T00:00:00Z",
 *   "fromEpochMillis": "2026-02-16T00:00:00Z",
 *   "toEpochSeconds": 1771165800,
 *   "toEpochMillis": 1771165800000,
 *   "events": [
 *     {"name": "User Login", "time": "2026-02-15T20:00:00Z"},
 *     {"name": "Order Placed", "time": "2026-02-15T21:00:00Z"},
 *     {"name": "Payment Confirmed", "time": "2026-02-16T00:00:00Z"}
 *   ]
 * }
 */
%dw 2.0
output application/json

fun epochToDateTime(epoch: Number): DateTime =
    epoch as DateTime {unit: "seconds"}

fun dateTimeToEpoch(dt: DateTime): Number =
    dt as Number {unit: "seconds"}

fun epochMillisToDateTime(epoch: Number): DateTime =
    epoch as DateTime {unit: "milliseconds"}

fun dateTimeToEpochMillis(dt: DateTime): Number =
    dt as Number {unit: "milliseconds"}
---
{
    fromEpochSeconds: epochToDateTime(payload.epochSeconds) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    fromEpochMillis: epochMillisToDateTime(payload.epochMillis) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    toEpochSeconds: dateTimeToEpoch(payload.isoDate as DateTime),
    toEpochMillis: dateTimeToEpochMillis(payload.isoDate as DateTime),
    events: payload.events map (event) -> {
        name: event.name,
        time: epochToDateTime(event.timestamp) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"}
    }
}

// Alternative 1 — inline conversion (no helper functions):
// payload.epochSeconds as DateTime {unit: "seconds"}

// Alternative 2 — current time as epoch:
// now() as Number {unit: "seconds"}

// Alternative 3 — epoch millis (JavaScript-style):
// now() as Number {unit: "milliseconds"}

// Alternative 4 — compare epochs for ordering:
// payload.events orderBy $.timestamp
