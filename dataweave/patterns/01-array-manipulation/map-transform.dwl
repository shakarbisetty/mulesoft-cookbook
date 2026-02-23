/**
 * Pattern: Map Transform
 * Category: Array Manipulation
 * Difficulty: Beginner
 *
 * Description: Transform each element in an array into a new shape. The most
 * common DataWeave operation — use it to reshape payloads, rename fields,
 * compute derived values, or build API responses from raw data.
 *
 * Input (application/json):
 * [
 *   {"firstName": "Alice", "lastName": "Chen", "salary": 95000, "currency": "USD"},
 *   {"firstName": "Bob", "lastName": "Martinez", "salary": 72000, "currency": "USD"},
 *   {"firstName": "Carol", "lastName": "Nguyen", "salary": 110000, "currency": "USD"}
 * ]
 *
 * Output (application/json):
 * [
 *   {"fullName": "Alice Chen", "annualSalary": "$95,000.00"},
 *   {"fullName": "Bob Martinez", "annualSalary": "$72,000.00"},
 *   {"fullName": "Carol Nguyen", "annualSalary": "$110,000.00"}
 * ]
 */
%dw 2.0
output application/json
---
payload map (employee) -> {
    fullName: employee.firstName ++ " " ++ employee.lastName,
    annualSalary: "\$" ++ (employee.salary as String {format: "#,###.00"})
}

// Alternative 1 — shorthand with $ (current item) and $$ (index):
// payload map {
//     fullName: $.firstName ++ " " ++ $.lastName,
//     annualSalary: "\$" ++ ($.salary as String {format: "#,###.00"})
// }

// Alternative 2 — map with index:
// payload map (employee, index) -> {
//     id: index + 1,
//     fullName: employee.firstName ++ " " ++ employee.lastName
// }
