/**
 * Pattern: Custom Types
 * Category: Type Coercion
 * Difficulty: Advanced
 * Description: Define and use custom types for type-safe transformations.
 * Custom types let you create domain-specific type aliases, enforce formats
 * during coercion, and make your DataWeave code self-documenting. Use with
 * the `type` keyword and `is` operator for validation.
 *
 * Input (application/json):
 * {
 *   "employees": [
 *     {
 *       "empId": "EMP001",
 *       "name": "Alice Chen",
 *       "salary": "95000"
 *     },
 *     {
 *       "empId": "EMP002",
 *       "name": "Bob Martinez",
 *       "salary": "72000"
 *     },
 *     {
 *       "empId": "EMP003",
 *       "name": "Carol Nguyen",
 *       "salary": "bad_data"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * {"employeeId": "EMP001", "fullName": "Alice Chen", "annualSalary": 95000, "hireDate": "2024-01-15", "isEngineering": true, "salaryValid": true},
 * {"employeeId": "EMP002", "fullName": "Bob Martinez", "annualSalary": 72000, "hireDate": "2025-06-20", "isEngineering": false, "salaryValid": true},
 * {"employeeId": "EMP003", "fullName": "Carol Nguyen", "annualSalary": 0, "hireDate": "2023-03-10", "isEngineering": true, "salaryValid": false}
 * ]
 */
%dw 2.0
output application/json
type EmployeeId = String {minLength: 6}
type Salary = Number
fun parseSalary(val: String): Salary | Null = val as Number default null
---
payload.employees map (emp) -> ({
  employeeId: emp.empId as EmployeeId,
  fullName: upper(emp.name),
  salary: parseSalary(emp.salary),
  isValid: (parseSalary(emp.salary) != null) and (emp.empId is String)
})
