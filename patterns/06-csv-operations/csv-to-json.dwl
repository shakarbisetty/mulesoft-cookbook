/**
 * Pattern: CSV to JSON
 * Category: CSV Operations
 * Difficulty: Beginner
 *
 * Description: Parse a CSV payload into a JSON array of objects, where the
 * first row provides the field names. Common when processing file-based
 * integrations, bulk imports, and data feeds from legacy systems that
 * export data as CSV/TSV files.
 *
 * Input (application/csv):
 * employeeId,firstName,lastName,department,salary,startDate
 * EMP001,Alice,Chen,Engineering,95000,2024-01-15
 * EMP002,Bob,Martinez,Marketing,72000,2025-06-20
 * EMP003,Carol,Nguyen,Engineering,110000,2023-03-10
 * EMP004,David,Kim,Sales,68000,2025-11-01
 *
 * Output (application/json):
 * [
 *   {"employeeId": "EMP001", "firstName": "Alice", "lastName": "Chen", "department": "Engineering", "salary": 95000, "startDate": "2024-01-15"},
 *   {"employeeId": "EMP002", "firstName": "Bob", "lastName": "Martinez", "department": "Marketing", "salary": 72000, "startDate": "2025-06-20"},
 *   {"employeeId": "EMP003", "firstName": "Carol", "lastName": "Nguyen", "department": "Engineering", "salary": 110000, "startDate": "2023-03-10"},
 *   {"employeeId": "EMP004", "firstName": "David", "lastName": "Kim", "department": "Sales", "salary": 68000, "startDate": "2025-11-01"}
 * ]
 */
%dw 2.0
output application/json
---
payload map (row) -> {
    employeeId: row.employeeId,
    firstName: row.firstName,
    lastName: row.lastName,
    department: row.department,
    salary: row.salary as Number,
    startDate: row.startDate
}

// Alternative 1 — pass through directly (DW auto-parses CSV with headers):
// %dw 2.0
// output application/json
// ---
// payload
// Note: All values come as strings by default

// Alternative 2 — CSV without headers (access by index):
// input payload application/csv header=false
// ---
// payload map (row) -> {
//     employeeId: row.column_0,
//     firstName: row.column_1,
//     lastName: row.column_2
// }

// Alternative 3 — filter rows during conversion:
// payload filter ($.department == "Engineering") map { ... }
