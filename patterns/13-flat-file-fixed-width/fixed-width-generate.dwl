/**
 * Pattern: Fixed-Width Generate
 * Category: Flat File & Fixed-Width
 * Difficulty: Intermediate
 *
 * Description: Generate fixed-width (positional) output from JSON data.
 * Pad fields to exact widths with proper alignment (left-align strings,
 * right-align numbers, zero-pad numeric codes).
 *
 * Input (application/json):
 * [
 *   { "empId": "12345", "name": "John Doe", "dept": "Engineering", "salary": 95000, "startDate": "2020-01-15" },
 *   { "empId": "67890", "name": "Jane Smith", "dept": "Marketing", "salary": 82000, "startDate": "2021-06-01" },
 *   { "empId": "11111", "name": "Bob Johnson", "dept": "Sales", "salary": 78500, "startDate": "2019-11-20" }
 * ]
 *
 * Output (text/plain):
 * 12345John Doe            Engineering     000095000.002020-01-15
 * 67890Jane Smith           Marketing       000082000.002021-06-01
 * 11111Bob Johnson          Sales           000078500.002019-11-20
 *
 * Field layout:
 *   EmpID:     5 chars, left-aligned
 *   Name:      20 chars, left-aligned
 *   Dept:      16 chars, left-aligned
 *   Salary:    12 chars, right-aligned zero-padded with 2 decimals
 *   StartDate: 10 chars
 */
%dw 2.0
output text/plain

// Left-pad string with a character
fun lpad(s: String, len: Number, ch: String): String =
    if (sizeOf(s) >= len) s[0 to (len - 1)]
    else (ch * (len - sizeOf(s))) ++ s

// Right-pad string with a character
fun rpad(s: String, len: Number, ch: String): String =
    if (sizeOf(s) >= len) s[0 to (len - 1)]
    else s ++ (ch * (len - sizeOf(s)))

// Format a number with zero-padding and decimals
fun formatAmount(n: Number, len: Number): String =
    lpad(n as String {format: "0.00"}, len, "0")
---
payload map (emp) ->
    rpad(emp.empId, 5, " ")
    ++ rpad(emp.name, 20, " ")
    ++ rpad(emp.dept, 16, " ")
    ++ formatAmount(emp.salary, 12)
    ++ emp.startDate
joinBy "\n"
