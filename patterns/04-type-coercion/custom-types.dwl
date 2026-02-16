/**
 * Pattern: Custom Types
 * Category: Type Coercion
 * Difficulty: Advanced
 *
 * Description: Define and use custom types for type-safe transformations.
 * Custom types let you create domain-specific type aliases, enforce formats
 * during coercion, and make your DataWeave code self-documenting. Use with
 * the `type` keyword and `is` operator for validation.
 *
 * Input (application/json):
 * {
 *   "employees": [
 *     {"id": "EMP001", "name": "Alice Chen", "salary": "95000", "startDate": "01/15/2024", "department": "Engineering"},
 *     {"id": "EMP002", "name": "Bob Martinez", "salary": "72000", "startDate": "06/20/2025", "department": "Marketing"},
 *     {"id": "EMP003", "name": "Carol Nguyen", "salary": "bad_data", "startDate": "03/10/2023", "department": "Engineering"}
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {"employeeId": "EMP001", "fullName": "Alice Chen", "annualSalary": 95000, "hireDate": "2024-01-15", "isEngineering": true, "salaryValid": true},
 *   {"employeeId": "EMP002", "fullName": "Bob Martinez", "annualSalary": 72000, "hireDate": "2025-06-20", "isEngineering": false, "salaryValid": true},
 *   {"employeeId": "EMP003", "fullName": "Carol Nguyen", "annualSalary": 0, "hireDate": "2023-03-10", "isEngineering": true, "salaryValid": false}
 * ]
 */
%dw 2.0
output application/json

type EmployeeId = String
type Currency = Number
type USDate = String {format: "MM/dd/yyyy"}

fun parseSalary(s: String): Currency =
    if (s matches /^\d+$/) s as Number
    else 0

fun isValidSalary(s: String): Boolean =
    s matches /^\d+$/

fun parseUSDate(s: String): String =
    (s as Date {format: "MM/dd/yyyy"}) as String {format: "yyyy-MM-dd"}
---
payload.employees map (emp) -> {
    employeeId: emp.id as EmployeeId,
    fullName: emp.name,
    annualSalary: parseSalary(emp.salary),
    hireDate: parseUSDate(emp.startDate),
    isEngineering: emp.department == "Engineering",
    salaryValid: isValidSalary(emp.salary)
}

// Alternative 1 — type checking with `is`:
// payload.value is String    // true if value is a string
// payload.value is Number    // true if value is a number
// payload.value is Array     // true if value is an array

// Alternative 2 — type coercion with default fallback:
// (payload.salary as Number) default 0

// Alternative 3 — define an object type:
// type Address = {
//     street: String,
//     city: String,
//     state: String,
//     zip: String
// }
