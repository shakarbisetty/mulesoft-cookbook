/**
 * Pattern: Zip Arrays
 * Category: Array Manipulation
 * Difficulty: Intermediate
 *
 * Description: Combine two arrays element-wise into an array of pairs (or merged
 * objects). Use when you have parallel arrays — e.g., a list of header names and
 * a list of values, or matched records from two systems that need to be joined
 * by position.
 *
 * Input (application/json):
 * {
 *   "headers": ["productName", "sku", "price", "inStock"],
 *   "rows": [
 *     ["Mechanical Keyboard", "SKU-100", 149.99, true],
 *     ["Wireless Mouse", "SKU-400", 29.99, true],
 *     ["USB-C Hub", "SKU-300", 49.99, false]
 *   ]
 * }
 *
 * Output (application/json):
 * [
 *   {"productName": "Mechanical Keyboard", "sku": "SKU-100", "price": 149.99, "inStock": true},
 *   {"productName": "Wireless Mouse", "sku": "SKU-400", "price": 29.99, "inStock": true},
 *   {"productName": "USB-C Hub", "sku": "SKU-300", "price": 49.99, "inStock": false}
 * ]
 */
%dw 2.0
output application/json
var headers = payload.headers
---
payload.rows map (row) ->
    (headers zip row) reduce (pair, acc = {}) ->
        acc ++ {(pair[0]): pair[1]}

// Alternative 1 — simple zip of two arrays into pairs:
// Input: [1, 2, 3] zip ["a", "b", "c"]
// Output: [[1, "a"], [2, "b"], [3, "c"]]

// Alternative 2 — zip two arrays into objects:
// var names = ["Alice", "Bob", "Carol"]
// var scores = [95, 87, 92]
// ---
// (names zip scores) map (pair) -> {
//     name: pair[0],
//     score: pair[1]
// }

// Alternative 3 — using zip with index for numbered results:
// var items = ["Laptop", "Mouse", "Keyboard"]
// var ids = (1 to sizeOf(items))
// ---
// (ids zip items) map (pair) -> {id: pair[0], product: pair[1]}
