/**
 * Pattern: Flatten Nested Arrays
 * Category: Array Manipulation
 * Difficulty: Intermediate
 *
 * Description: Flatten nested arrays into a single-level array. Common when
 * dealing with API responses that return arrays of arrays (e.g., orders with
 * line items, departments with employees) and you need a flat list.
 *
 * Input (application/json):
 * {
 *   "departments": [
 *     {
 *       "name": "Engineering",
 *       "employees": [
 *         {"id": "E001", "name": "Alice Chen", "role": "Senior Developer"},
 *         {"id": "E002", "name": "Bob Martinez", "role": "DevOps Engineer"}
 *       ]
 *     },
 *     {
 *       "name": "Marketing",
 *       "employees": [
 *         {"id": "M001", "name": "Carol Nguyen", "role": "Content Strategist"},
 *         {"id": "M002", "name": "David Kim", "role": "SEO Analyst"},
 *         {"id": "M003", "name": "Elena Rossi", "role": "Brand Manager"}
 *       ]
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {"id": "E001", "name": "Alice Chen", "role": "Senior Developer", "department": "Engineering"},
 *   {"id": "E002", "name": "Bob Martinez", "role": "DevOps Engineer", "department": "Engineering"},
 *   {"id": "M001", "name": "Carol Nguyen", "role": "Content Strategist", "department": "Marketing"},
 *   {"id": "M002", "name": "David Kim", "role": "SEO Analyst", "department": "Marketing"},
 *   {"id": "M003", "name": "Elena Rossi", "role": "Brand Manager", "department": "Marketing"}
 * ]
 */
%dw 2.0
output application/json
---
payload.departments flatMap (dept) ->
    dept.employees map (emp) -> emp ++ {department: dept.name}

// Alternative 1 — using flatten on a mapped array:
// flatten(
//     payload.departments map (dept) ->
//         dept.employees map (emp) -> emp ++ {department: dept.name}
// )

// Alternative 2 — simple flatten for already-nested arrays:
// Input: [[1, 2], [3, 4], [5, 6]]
// flatten(payload)
// Output: [1, 2, 3, 4, 5, 6]
