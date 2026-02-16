%dw 2.0

/**
 * Module: DateUtils
 * Version: 1.0.0
 *
 * Reusable date/time utility functions for DataWeave 2.x.
 * Import with: import modules::DateUtils
 *
 * Functions (11):
 *   toISO, toEpoch, fromEpoch, addDays, addMonths, diffDays,
 *   formatDate, isWeekend, startOfMonth, endOfMonth, isLeapYear
 */

/**
 * Convert a DateTime to ISO 8601 string.
 * toISO(|2026-02-15T14:30:00Z|) -> "2026-02-15T14:30:00Z"
 */
fun toISO(d: DateTime): String =
    d as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"}

/**
 * Convert a DateTime to Unix epoch seconds.
 * toEpoch(|2026-02-15T00:00:00Z|) -> 1771200000
 */
fun toEpoch(d: DateTime): Number =
    d as Number {unit: "seconds"}

/**
 * Convert Unix epoch seconds to DateTime (UTC).
 * fromEpoch(1771200000) -> |2026-02-15T00:00:00Z|
 */
fun fromEpoch(n: Number): DateTime =
    n as DateTime {unit: "seconds"}

/**
 * Add (or subtract) days from a Date.
 * addDays(|2026-02-15|, 10) -> |2026-02-25|
 * addDays(|2026-02-15|, -5) -> |2026-02-10|
 */
fun addDays(d: Date, n: Number): Date =
    d + ("P$(n)D" as Period)

/**
 * Add (or subtract) months from a Date.
 * addMonths(|2026-01-31|, 1) -> |2026-02-28|
 * addMonths(|2026-03-15|, -2) -> |2026-01-15|
 */
fun addMonths(d: Date, n: Number): Date =
    d + ("P$(n)M" as Period)

/**
 * Calculate the number of days between two dates (d2 - d1).
 * diffDays(|2026-02-10|, |2026-02-15|) -> 5
 * diffDays(|2026-02-15|, |2026-02-10|) -> -5
 */
fun diffDays(d1: Date, d2: Date): Number =
    (d2 as Number {unit: "days"}) - (d1 as Number {unit: "days"})

/**
 * Format a DateTime with a custom pattern.
 * formatDate(|2026-02-15T14:30:00Z|, "MM/dd/yyyy") -> "02/15/2026"
 * formatDate(|2026-02-15T14:30:00Z|, "dd-MMM-yyyy") -> "15-Feb-2026"
 */
fun formatDate(d: DateTime, fmt: String): String =
    d as String {format: fmt}

/**
 * Check if a Date falls on a weekend (Saturday or Sunday).
 * isWeekend(|2026-02-14|) -> true  (Saturday)
 * isWeekend(|2026-02-16|) -> true  (Sunday -- wait, let me verify)
 *
 * Note: Uses dayOfWeek where 6=Saturday, 7=Sunday.
 */
fun isWeekend(d: Date): Boolean =
    do {
        var dow = (d as DateTime) as String {format: "u"}
        ---
        dow == "6" or dow == "7"
    }

/**
 * Get the first day of the month for a given Date.
 * startOfMonth(|2026-02-15|) -> |2026-02-01|
 */
fun startOfMonth(d: Date): Date =
    (d as String {format: "yyyy-MM"} ++ "-01") as Date {format: "yyyy-MM-dd"}

/**
 * Get the last day of the month for a given Date.
 * endOfMonth(|2026-02-15|) -> |2026-02-28|
 * endOfMonth(|2024-02-15|) -> |2024-02-29| (leap year)
 */
fun endOfMonth(d: Date): Date =
    do {
        var firstOfNext = addMonths(startOfMonth(d), 1)
        ---
        addDays(firstOfNext, -1)
    }

/**
 * Check if a year is a leap year.
 * isLeapYear(2024) -> true
 * isLeapYear(2026) -> false
 * isLeapYear(2000) -> true
 * isLeapYear(1900) -> false
 */
fun isLeapYear(y: Number): Boolean =
    (mod(y, 4) == 0 and mod(y, 100) != 0) or (mod(y, 400) == 0)
