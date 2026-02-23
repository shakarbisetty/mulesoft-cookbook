# 08 — Date/Time

Dates and times are one of the biggest sources of bugs in integration. Different systems use different formats, timezones, and epoch conventions. These patterns cover formatting, timezone conversion, arithmetic, and epoch handling.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Date Formatting | [`date-formatting.dwl`](date-formatting.dwl) | Beginner | Format dates into various string representations |
| 2 | Timezone Conversion | [`timezone-conversion.dwl`](timezone-conversion.dwl) | Intermediate | Convert datetimes between timezones |
| 3 | Date Arithmetic | [`date-arithmetic.dwl`](date-arithmetic.dwl) | Intermediate | Add/subtract periods and durations |
| 4 | Epoch Conversion | [`epoch-conversion.dwl`](epoch-conversion.dwl) | Intermediate | Convert between epoch timestamps and dates |

---

## DataWeave Date Types

| Type | Example | Description |
|------|---------|-------------|
| `Date` | `2026-02-15` | Date only (no time, no zone) |
| `Time` | `14:30:00` | Time only (no date, no zone) |
| `DateTime` | `2026-02-15T14:30:00Z` | Date + time + timezone |
| `LocalDateTime` | `2026-02-15T14:30:00` | Date + time, no timezone |
| `LocalTime` | `14:30:00` | Time, no timezone |
| `Period` | `\|P1Y2M3D\|` | Year/month/day duration |
| `Duration` | `\|PT1H30M\|` | Hour/minute/second duration |

---

## Tips

- **Always normalize to UTC for storage:** Convert to UTC (`>> |+00:00|`) before persisting. Convert to local time only for display.
- **Period vs Duration:** Use `|P...|` (Period) for days/months/years. Use `|PT...|` (Duration) for hours/minutes/seconds.
- **Date difference:** `(date1 - date2).days` gives the number of days between two dates.
- **Epoch units matter:** Specify `{unit: "seconds"}` or `{unit: "milliseconds"}` when converting to/from epoch. Mixing them up is a common bug.

---

[Back to all patterns](../../README.md)
