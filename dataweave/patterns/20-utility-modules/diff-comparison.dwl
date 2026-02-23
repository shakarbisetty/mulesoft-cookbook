/**
 * Pattern: Structural Diff Between Two Payloads
 * Category: Utility Modules
 * Difficulty: Intermediate
 *
 * Description: Use dw::util::Diff to compare two values structurally and
 * identify exact differences. Invaluable for API response regression testing,
 * config change detection, migration validation, and audit logging where
 * you need to know precisely what changed.
 *
 * Input (application/json):
 * {
 *   "expected": {
 *     "name": "Alice Chen",
 *     "age": 30,
 *     "roles": ["admin", "editor"],
 *     "address": {"city": "Portland", "state": "OR"}
 *   },
 *   "actual": {
 *     "name": "Alice Chen",
 *     "age": 31,
 *     "roles": ["admin", "viewer"],
 *     "address": {"city": "Seattle", "state": "WA"}
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "identical": false,
 *   "differenceCount": 4,
 *   "differences": [
 *     {"path": "age", "expected": 30, "actual": 31},
 *     {"path": "roles[1]", "expected": "editor", "actual": "viewer"},
 *     {"path": "address.city", "expected": "Portland", "actual": "Seattle"},
 *     {"path": "address.state", "expected": "OR", "actual": "WA"}
 *   ]
 * }
 */
%dw 2.0
import diff from dw::util::Diff
output application/json

var result = diff(payload.expected, payload.actual)
---
{
    identical: result.matches,
    differenceCount: sizeOf(result.diffs default []),
    differences: (result.diffs default []) map (d) -> {
        path: d.path,
        expected: d.expected,
        actual: d.actual
    }
}

// Alternative 1 — diff for migration validation (DW 1.0 vs 2.0 output):
// var dw1Output = read(payload.dw1Result, "application/json")
// var dw2Output = read(payload.dw2Result, "application/json")
// var migrationDiff = diff(dw1Output, dw2Output)
// ---
// if (migrationDiff.matches) "Migration OK" else migrationDiff.diffs

// Alternative 2 — config change audit log:
// {
//     timestamp: now(),
//     changedBy: vars.userId,
//     changes: diff(vars.oldConfig, vars.newConfig).diffs
//         map (d) -> "$(d.path): $(d.expected) → $(d.actual)"
// }
