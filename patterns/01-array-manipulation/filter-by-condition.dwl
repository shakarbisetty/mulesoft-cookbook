/**
 * Pattern: Filter Array by Condition
 * Category: Array Manipulation
 * Difficulty: Beginner
 *
 * Description: Filter an array to include only elements matching a condition.
 * Use this whenever you need to narrow down a list based on a predicate —
 * active users, in-stock products, orders above a threshold, etc.
 *
 * Input (application/json):
 * [
 *   {"name": "Alice Chen", "age": 30, "department": "Engineering", "active": true},
 *   {"name": "Bob Martinez", "age": 25, "department": "Marketing", "active": false},
 *   {"name": "Carol Nguyen", "age": 35, "department": "Engineering", "active": true},
 *   {"name": "David Kim", "age": 28, "department": "Sales", "active": false},
 *   {"name": "Elena Rossi", "age": 32, "department": "Engineering", "active": true}
 * ]
 *
 * Output (application/json):
 * [
 *   {"name": "Alice Chen", "age": 30, "department": "Engineering", "active": true},
 *   {"name": "Carol Nguyen", "age": 35, "department": "Engineering", "active": true},
 *   {"name": "Elena Rossi", "age": 32, "department": "Engineering", "active": true}
 * ]
 */
%dw 2.0
output application/json
---
payload filter (employee) -> employee.active == true

// Alternative 1 — shorthand with $ (anonymous parameter):
// payload filter $.active

// Alternative 2 — multiple conditions:
// payload filter (employee) -> employee.active and employee.department == "Engineering"

// Alternative 3 — filter with index (second param is the index):
// payload filter (employee, index) -> index < 3
