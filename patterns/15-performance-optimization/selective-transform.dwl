/**
 * Pattern: Selective Transform (Delta Processing)
 * Category: Performance & Optimization
 * Difficulty: Intermediate
 *
 * Description: Transform only changed fields between two versions of a
 * record. Useful for delta/incremental sync between systems, reducing
 * API payload size and avoiding unnecessary updates.
 *
 * Input (application/json):
 * {
 *   "previous": {
 *     "id": "CUST-001",
 *     "name": "John Doe",
 *     "email": "john@example.com",
 *     "phone": "+1-555-0100",
 *     "address": { "city": "Austin", "state": "TX", "zip": "78701" },
 *     "tier": "Silver",
 *     "lastModified": "2026-01-01T00:00:00Z"
 *   },
 *   "current": {
 *     "id": "CUST-001",
 *     "name": "John Doe",
 *     "email": "john.doe@newdomain.com",
 *     "phone": "+1-555-0100",
 *     "address": { "city": "Dallas", "state": "TX", "zip": "75201" },
 *     "tier": "Gold",
 *     "lastModified": "2026-02-18T10:30:00Z"
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "id": "CUST-001",
 *   "hasChanges": true,
 *   "changedFields": ["email", "address", "tier", "lastModified"],
 *   "delta": {
 *     "email": { "from": "john@example.com", "to": "john.doe@newdomain.com" },
 *     "address": { "from": { "city": "Austin", "zip": "78701" }, "to": { "city": "Dallas", "zip": "75201" } },
 *     "tier": { "from": "Silver", "to": "Gold" },
 *     "lastModified": { "from": "2026-01-01T00:00:00Z", "to": "2026-02-18T10:30:00Z" }
 *   },
 *   "patchPayload": {
 *     "email": "john.doe@newdomain.com",
 *     "address": { "city": "Dallas", "state": "TX", "zip": "75201" },
 *     "tier": "Gold"
 *   }
 * }
 */
%dw 2.0
output application/json

var prev = payload.previous
var curr = payload.current
var ignoredFields = ["lastModified"]

// Compare two values (deep comparison for objects)
fun isDifferent(a: Any, b: Any): Boolean =
    write(a, "application/json") != write(b, "application/json")

// Find all changed fields
var changes = (curr pluck (value, key) -> {
        field: key as String,
        changed: isDifferent(prev[key as String], value),
        oldValue: prev[key as String],
        newValue: value
    })
    filter $.changed
    filter !(ignoredFields contains $.field)
---
{
    id: curr.id,
    hasChanges: !isEmpty(changes),
    changedFields: changes.field,
    delta: changes reduce (change, acc = {}) ->
        acc ++ { (change.field): { from: change.oldValue, to: change.newValue } },
    patchPayload: if (isEmpty(changes)) {}
        else changes reduce (change, acc = {}) ->
            acc ++ { (change.field): change.newValue }
}
