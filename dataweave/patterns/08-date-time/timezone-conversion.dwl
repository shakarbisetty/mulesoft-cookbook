/**
 * Pattern: Timezone Conversion
 * Category: Date/Time
 * Difficulty: Intermediate
 * Description: Convert datetimes between timezones using the >> operator.
 * Critical for global integrations where systems operate in different
 * timezones — converting UTC to local time, normalizing timestamps
 * for storage, and displaying times in user-local timezones.
 *
 * Input (application/json):
 * {
 *   "eventTime": "2026-02-15T14:30:00Z",
 *   "targetZones": [
 *     {
 *       "name": "New York",
 *       "offset": "-05:00"
 *     },
 *     {
 *       "name": "Tokyo",
 *       "offset": "+09:00"
 *     },
 *     {
 *       "name": "Kolkata",
 *       "offset": "+05:30"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "originalUTC": "2026-02-15T14:30:00Z",
 * "newYork": "2026-02-15T09:30:00-05:00",
 * "losAngeles": "2026-02-15T06:30:00-08:00",
 * "london": "2026-02-15T14:30:00Z",
 * "tokyo": "2026-02-15T23:30:00+09:00",
 * "kolkata": "2026-02-15T20:00:00+05:30",
 * "meetingInUTC": "2026-02-15T14:00:00Z",
 * "meetingInTokyo": "2026-02-15T23:00:00+09:00"
 * }
 */
%dw 2.0
output application/json
var utcTime = payload.eventTime as DateTime
---
{
  originalUTC: utcTime as String {format: "yyyy-MM-dd HH:mm:ss"},
  conversions: payload.targetZones map (zone) -> ({
    city: zone.name,
    localTime: (utcTime >> (zone.offset as TimeZone)) as String {format: "yyyy-MM-dd HH:mm:ss"}
  })
}
