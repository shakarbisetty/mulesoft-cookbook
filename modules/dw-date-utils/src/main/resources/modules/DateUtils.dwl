%dw 2.0

/**
 * Module: DateUtils
 * Version: 1.0.0
 *
 * Reusable date/time utility functions for DataWeave 2.x.
 * Import with: import modules::DateUtils
 *
 * Functions (14):
 *   toISO, toEpoch, fromEpoch, addDays, addMonths, diffDays,
 *   formatDate, isWeekend, startOfMonth, endOfMonth, isLeapYear,
 *   toBusinessDay, quarter, daysBetweenBusiness
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
 * isWeekend(|2026-02-15|) -> true  (Sunday)
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

/**
 * Adjust a date to the next business day (Mon-Fri).
 * If the date falls on Saturday, returns the following Monday.
 * If on Sunday, returns the following Monday.
 * toBusinessDay(|2026-02-14|) -> |2026-02-16| (Saturday -> Monday)
 * toBusinessDay(|2026-02-13|) -> |2026-02-13| (Friday -> Friday)
 */
fun toBusinessDay(d: Date): Date =
    do {
        var dow = (d as DateTime) as String {format: "u"}
        ---
        if (dow == "6") addDays(d, 2)
        else if (dow == "7") addDays(d, 1)
        else d
    }

/**
 * Get the fiscal quarter (1-4) for a given date.
 * quarter(|2026-01-15|) -> 1
 * quarter(|2026-06-15|) -> 2
 * quarter(|2026-09-30|) -> 3
 * quarter(|2026-12-01|) -> 4
 */
fun quarter(d: Date): Number =
    do {
        var month = d.month as Number
        ---
        ceil(month / 3)
    }

/**
 * Count business days (Mon-Fri) between two dates (exclusive of end date).
 * daysBetweenBusiness(|2026-02-09|, |2026-02-13|) -> 4  (Mon-Thu)
 * daysBetweenBusiness(|2026-02-09|, |2026-02-16|) -> 5  (Mon-Fri, skip Sat/Sun)
 */
fun daysBetweenBusiness(d1: Date, d2: Date): Number =
    do {
        var totalDays = diffDays(d1, d2)
        var fullWeeks = floor(totalDays / 7)
        var remainingDays = mod(totalDays, 7)
        var startDow = ((d1 as DateTime) as String {format: "u"}) as Number
        var extraWeekendDays = (0 to (remainingDays - 1)) reduce ((i, acc = 0) ->
            do {
                var currentDow = mod(startDow + i - 1, 7) + 1
                ---
                if (currentDow == 6 or currentDow == 7) acc + 1
                else acc
            }
        )
        ---
        totalDays - (fullWeeks * 2) - (extraWeekendDays default 0)
    }
