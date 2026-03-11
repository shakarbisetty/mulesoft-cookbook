/**
 * Pattern: Lazy Evaluation
 * Category: Performance & Optimization
 * Difficulty: Advanced
 * Description: Use DataWeave's lazy evaluation and deferred output to
 * process large payloads without loading the entire dataset into memory.
 * Critical for transformations on payloads > 10 MB.
 *
 * Input (application/json):
 * [
 *   {
 *     "id": 1,
 *     "name": "alice",
 *     "status": "active",
 *     "score": 92
 *   },
 *   {
 *     "id": 2,
 *     "name": "bob",
 *     "status": "inactive",
 *     "score": 45
 *   },
 *   {
 *     "id": 3,
 *     "name": "carol",
 *     "status": "active",
 *     "score": 88
 *   },
 *   {
 *     "id": 4,
 *     "name": "dan",
 *     "status": "inactive",
 *     "score": 60
 *   },
 *   {
 *     "id": 5,
 *     "name": "eve",
 *     "status": "active",
 *     "score": 97
 *   }
 * ]
 *
 * Output (application/json):
 * [
 * { "id": 1, "name": "ALICE", "score": 85 },
 * { "id": 3, "name": "CAROL", "score": 91 },
 * ...
 * ]
 */
%dw 2.0
output application/json
---
payload
    filter $.status == "active"
    map (item) -> ({
        id: item.id,
        name: upper(item.name),
        score: item.score
    })
