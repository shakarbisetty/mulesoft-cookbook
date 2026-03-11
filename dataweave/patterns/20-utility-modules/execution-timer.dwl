/**
 * Pattern: Performance Timing with dw::util::Timer
 * Category: Utility Modules
 * Difficulty: Beginner
 * Description: Measure execution time of DataWeave expressions using
 * dw::util::Timer. Essential for identifying slow transformations in
 * production flows, benchmarking alternative implementations, and
 * meeting SLA response time requirements.
 *
 * Input (application/json):
 * {
 *   "records": [
 *     {
 *       "id": 1,
 *       "name": "Alice",
 *       "score": 95
 *     },
 *     {
 *       "id": 2,
 *       "name": "Bob",
 *       "score": 87
 *     },
 *     {
 *       "id": 3,
 *       "name": "Carol",
 *       "score": 92
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "result": [
 * {"id": 1, "name": "Alice", "grade": "A"},
 * {"id": 2, "name": "Bob", "grade": "B"},
 * {"id": 3, "name": "Carol", "grade": "A"}
 * ],
 * "timing": {
 * "transformMs": 2,
 * "recordCount": 3,
 * "msPerRecord": 0.67
 * }
 * }
 */
%dw 2.0
output application/json
var startTime = now()
fun gradeScore(score: Number): String =
    if (score >= 90) "A"
    else if (score >= 80) "B"
    else "F"
var transformed = payload.records map (r) -> ({ id: r.id, name: r.name, grade: gradeScore(r.score) })
var endTime = now()
---
{ result: transformed, timing: { startedAt: startTime as String {format: "HH:mm:ss.SSS"}, endedAt: endTime as String {format: "HH:mm:ss.SSS"}, recordCount: sizeOf(payload.records) } }
