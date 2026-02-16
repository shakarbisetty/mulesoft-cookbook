# dw-date-utils

> 11 reusable date/time utility functions for DataWeave 2.x

---

## Installation

Add to your Mule project `pom.xml`:

```xml
<dependency>
    <groupId>{ORG_ID}</groupId>
    <artifactId>dw-date-utils</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::DateUtils
output application/json
---
{
    iso: DateUtils::toISO(|2026-02-15T14:30:00Z|),           // "2026-02-15T14:30:00+0000"
    epoch: DateUtils::toEpoch(|2026-02-15T00:00:00Z|),       // 1771200000
    fromEpoch: DateUtils::fromEpoch(0),                        // |1970-01-01T00:00:00Z|
    tenDaysLater: DateUtils::addDays(|2026-02-15|, 10),       // |2026-02-25|
    nextMonth: DateUtils::addMonths(|2026-01-31|, 1),         // |2026-02-28|
    daysBetween: DateUtils::diffDays(|2026-02-10|, |2026-02-15|), // 5
    formatted: DateUtils::formatDate(|2026-02-15T14:30:00Z|, "MM/dd/yyyy"), // "02/15/2026"
    weekend: DateUtils::isWeekend(|2026-02-14|),               // true (Saturday)
    firstDay: DateUtils::startOfMonth(|2026-02-15|),           // |2026-02-01|
    lastDay: DateUtils::endOfMonth(|2026-02-15|),              // |2026-02-28|
    leap: DateUtils::isLeapYear(2024)                          // true
}
```

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `toISO` | `(d: DateTime) -> String` | ISO 8601 string |
| `toEpoch` | `(d: DateTime) -> Number` | Unix timestamp (seconds) |
| `fromEpoch` | `(n: Number) -> DateTime` | Epoch seconds to DateTime |
| `addDays` | `(d: Date, n: Number) -> Date` | Add/subtract days |
| `addMonths` | `(d: Date, n: Number) -> Date` | Add/subtract months |
| `diffDays` | `(d1: Date, d2: Date) -> Number` | Days between two dates |
| `formatDate` | `(d: DateTime, fmt: String) -> String` | Custom date format |
| `isWeekend` | `(d: Date) -> Boolean` | Saturday/Sunday check |
| `startOfMonth` | `(d: Date) -> Date` | First day of month |
| `endOfMonth` | `(d: Date) -> Date` | Last day of month |
| `isLeapYear` | `(y: Number) -> Boolean` | Leap year check |

## Testing

26 MUnit test cases covering all 11 functions with basic, edge, and boundary inputs (leap years, month boundaries, negative offsets, epoch zero).

```bash
mvn clean test
```

## License

[MIT](../../LICENSE)
