/**
 * Pattern: Timezone Conversion
 * Category: Date/Time
 * Difficulty: Intermediate
 *
 * Description: Convert datetimes between timezones using the >> operator.
 * Critical for global integrations where systems operate in different
 * timezones — converting UTC to local time, normalizing timestamps
 * for storage, and displaying times in user-local timezones.
 *
 * Input (application/json):
 * {
 *   "eventTime": "2026-02-15T14:30:00Z",
 *   "meetingTime": "2026-02-15T09:00:00-05:00",
 *   "localTimezones": ["America/New_York", "America/Los_Angeles", "Europe/London", "Asia/Tokyo", "Asia/Kolkata"]
 * }
 *
 * Output (application/json):
 * {
 *   "originalUTC": "2026-02-15T14:30:00Z",
 *   "newYork": "2026-02-15T09:30:00-05:00",
 *   "losAngeles": "2026-02-15T06:30:00-08:00",
 *   "london": "2026-02-15T14:30:00Z",
 *   "tokyo": "2026-02-15T23:30:00+09:00",
 *   "kolkata": "2026-02-15T20:00:00+05:30",
 *   "meetingInUTC": "2026-02-15T14:00:00Z",
 *   "meetingInTokyo": "2026-02-15T23:00:00+09:00"
 * }
 */
%dw 2.0
output application/json
var utcTime = payload.eventTime as DateTime
var meeting = payload.meetingTime as DateTime
---
{
    originalUTC: utcTime as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    newYork: (utcTime >> |-05:00|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    losAngeles: (utcTime >> |-08:00|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    london: (utcTime >> |+00:00|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    tokyo: (utcTime >> |+09:00|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    kolkata: (utcTime >> |+05:30|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    meetingInUTC: (meeting >> |+00:00|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
    meetingInTokyo: (meeting >> |+09:00|) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"}
}

// Alternative 1 — normalize everything to UTC before storage:
// payload.timestamps map (ts) -> (ts as DateTime >> |+00:00|)

// Alternative 2 — convert with offset literal:
// payload.eventTime as DateTime >> |-05:00|

// Alternative 3 — get just the offset from a DateTime:
// (payload.eventTime as DateTime).timeZone
// Output: "Z" (for UTC)

// Tip: The >> operator shifts the time AND changes the zone.
// It does NOT just relabel the timezone — it recalculates the time.
