# 04 — Type Coercion

Integration is all about bridging type mismatches between systems. Dates arrive as strings, booleans come as "Y"/"N", numbers are embedded in text. These patterns cover the essential type conversions every MuleSoft developer needs.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | String to Date | [`string-to-date.dwl`](string-to-date.dwl) | Intermediate | Parse date strings into Date/DateTime types |
| 2 | Number Formatting | [`number-formatting.dwl`](number-formatting.dwl) | Beginner | Format numbers with patterns (currency, padding, etc.) |
| 3 | Boolean Handling | [`boolean-handling.dwl`](boolean-handling.dwl) | Beginner | Convert between bool, "Y"/"N", 1/0, "true"/"false" |
| 4 | Custom Types | [`custom-types.dwl`](custom-types.dwl) | Advanced | Define domain-specific types and type-safe coercions |

---

## Core Functions Used

| Function | Purpose | Docs |
|----------|---------|------|
| `as` | Type coercion operator | [as](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-as) |
| `is` | Type check operator | [is](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-is) |
| `default` | Fallback for null/failed coercion | [default](https://docs.mulesoft.com/dataweave/latest/dw-core-functions-default) |
| `type` | Custom type definition | [DataWeave Type System](https://docs.mulesoft.com/dataweave/latest/dataweave-type-system) |

---

## Common Format Patterns

| Type | Pattern | Example |
|------|---------|---------|
| Date | `yyyy-MM-dd` | 2026-02-15 |
| DateTime | `yyyy-MM-dd'T'HH:mm:ssZ` | 2026-02-15T14:30:00Z |
| US Date | `MM/dd/yyyy` | 02/15/2026 |
| European Date | `dd.MM.yyyy` | 15.02.2026 |
| Number (currency) | `#,##0.00` | 1,299.50 |
| Number (zero-padded) | `00000` | 00042 |
| Number (percentage) | `0.00%` | 95.34% |

---

## Tips

- **Format strings use Java patterns:** Date formats follow `java.time.format.DateTimeFormatter`, number formats follow `java.text.DecimalFormat`.
- **`as` with `default`:** Always pair coercion with `default` when input may be null or unparseable: `payload.date as Date default now()`.
- **Boolean coercion:** `"true" as Boolean` works, but `"Y" as Boolean` does not. Use explicit mapping for non-standard boolean representations.

---

[Back to all patterns](../../README.md)
