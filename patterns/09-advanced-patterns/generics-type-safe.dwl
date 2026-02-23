/**
 * Pattern: Type-Safe Functions with Call-Site Generics
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Use DataWeave 2.5's call-site type parameters to write
 * reusable, type-safe utility functions. Specify generic types at the
 * call site — like Java/TypeScript generics — so the compiler validates
 * types without losing flexibility.
 *
 * Input (application/json):
 * {
 *   "numbers": [3, 1, 4, 1, 5, 9, 2, 6, 5, 3],
 *   "strings": ["banana", "apple", "cherry", "date"],
 *   "records": [
 *     {"name": "Carol", "score": 92},
 *     {"name": "Alice", "score": 95},
 *     {"name": "Bob", "score": 87}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "topNumber": 9,
 *   "topString": "date",
 *   "topScorer": {"name": "Alice", "score": 95},
 *   "numberStats": {"min": 1, "max": 9, "range": 8},
 *   "uniqueSorted": [1, 2, 3, 4, 5, 6, 9]
 * }
 */
%dw 2.0
output application/json

// Generic top-N function — works with any comparable type
fun topN<T>(items: Array<T>, n: Number, comparator: (T) -> Comparable): Array<T> =
    (items orderBy -comparator($))[0 to (n - 1)]

// Generic pipeline function — chain transformations
fun pipe<T>(value: T, fns: Array<(T) -> T>): T =
    fns reduce (fn, acc = value) -> fn(acc)
---
{
    topNumber: max<Number>(payload.numbers),
    topString: max<String>(payload.strings),
    topScorer: topN<{name: String, score: Number}>(
        payload.records, 1, (r) -> r.score
    )[0],
    numberStats: {
        min: min<Number>(payload.numbers),
        max: max<Number>(payload.numbers),
        range: max<Number>(payload.numbers) - min<Number>(payload.numbers)
    },
    uniqueSorted: pipe<Array<Number>>(payload.numbers, [
        (arr) -> arr distinctBy $,
        (arr) -> arr orderBy $
    ])
}

// Alternative 1 — generic safe-get with default:
// fun safeGet<T>(obj: Object, key: String, fallback: T): T =
//     obj[key] default fallback
// safeGet<Number>(payload, "missing", 0)  // returns 0

// Alternative 2 — generic collection operations:
// fun firstMatch<T>(items: Array<T>, pred: (T) -> Boolean): T | Null =
//     (items filter pred($))[0] default null
