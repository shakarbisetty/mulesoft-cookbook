/**
 * Pattern: Performance Timing with dw::util::Timer
 * Category: Utility Modules
 * Difficulty: Beginner
 *
 * Description: Measure execution time of DataWeave expressions using
 * dw::util::Timer. Essential for identifying slow transformations in
 * production flows, benchmarking alternative implementations, and
 * meeting SLA response time requirements.
 *
 * Input (application/json):
 * {
 *   "records": [
 *     {"id": 1, "name": "Alice", "score": 95},
 *     {"id": 2, "name": "Bob", "score": 87},
 *     {"id": 3, "name": "Carol", "score": 92}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "result": [
 *     {"id": 1, "name": "Alice", "grade": "A"},
 *     {"id": 2, "name": "Bob", "grade": "B"},
 *     {"id": 3, "name": "Carol", "grade": "A"}
 *   ],
 *   "timing": {
 *     "transformMs": 2,
 *     "recordCount": 3,
 *     "msPerRecord": 0.67
 *   }
 * }
 */
%dw 2.0
import currentMilliseconds from dw::util::Timer
output application/json

var startTime = currentMilliseconds()

fun gradeScore(score: Number): String =
    if (score >= 90) "A"
    else if (score >= 80) "B"
    else if (score >= 70) "C"
    else "F"

var transformed = payload.records map (r) -> {
    id: r.id,
    name: r.name,
    grade: gradeScore(r.score)
}

var endTime = currentMilliseconds()
var elapsed = endTime - startTime
---
{
    result: transformed,
    timing: {
        transformMs: elapsed,
        recordCount: sizeOf(payload.records),
        msPerRecord: if (sizeOf(payload.records) > 0)
            (elapsed / sizeOf(payload.records)) round 2
            else 0
    }
}

// Alternative 1 — compare two implementation speeds:
// var t1 = currentMilliseconds()
// var approach1 = payload.records map (r) -> r mapObject (v,k) -> {(upper(k)): v}
// var t2 = currentMilliseconds()
// var approach2 = payload.records map (r) -> r pluck (v,k) -> {(upper(k)): v}
// var t3 = currentMilliseconds()
// ---
// {approach1Time: t2-t1, approach2Time: t3-t2, faster: if (t2-t1 < t3-t2) "map" else "pluck"}

// Alternative 2 — SLA threshold check:
// var elapsed = endTime - startTime
// var slaMs = 500
// ---
// if (elapsed > slaMs) logWarn("Transform exceeded SLA: $(elapsed)ms > $(slaMs)ms")
