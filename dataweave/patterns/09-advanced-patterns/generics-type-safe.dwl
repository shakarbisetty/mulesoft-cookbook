/**
 * Pattern: Type-Safe Functions with Call-Site Generics
 * Category: Advanced Patterns
 * Difficulty: Advanced
 * Description: Use DataWeave 2.5's call-site type parameters to write
 * reusable, type-safe utility functions. Specify generic types at the
 * call site — like Java/TypeScript generics — so the compiler validates
 * types without losing flexibility.
 *
 * Input (application/json):
 * {
 *   "numbers": [
 *     3,
 *     1,
 *     4,
 *     1,
 *     5,
 *     9,
 *     2,
 *     6
 *   ],
 *   "strings": [
 *     "banana",
 *     "apple",
 *     "cherry"
 *   ],
 *   "records": [
 *     {
 *       "name": "Carol",
 *       "score": 92
 *     },
 *     {
 *       "name": "Alice",
 *       "score": 95
 *     },
 *     {
 *       "name": "Bob",
 *       "score": 87
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "topNumber": 9,
 * "topString": "date",
 * "topScorer": {"name": "Alice", "score": 95},
 * "numberStats": {"min": 1, "max": 9, "range": 8},
 * "uniqueSorted": [1, 2, 3, 4, 5, 6, 9]
 * }
 */
%dw 2.0
output application/json
fun topN<T>(items: Array<T>, n: Number, comp: (T) -> Comparable): Array<T> =
    (items orderBy -comp($))[0 to (n - 1)]
fun pipe<T>(value: T, fns: Array<(T) -> T>): T =
    fns reduce (fn, acc = value) -> fn(acc)
---
{ topScorer: topN<{name: String, score: Number}>(payload.records, 1, (r) -> r.score)[0],
  stats: { min: min<Number>(payload.numbers), max: max<Number>(payload.numbers) },
  sorted: pipe<Array<Number>>(payload.numbers, [(arr) -> arr distinctBy $, (arr) -> arr orderBy $]) }
