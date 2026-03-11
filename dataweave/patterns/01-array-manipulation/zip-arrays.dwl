/**
 * Pattern: Zip Arrays
 * Category: Array Manipulation
 * Difficulty: Intermediate
 * Description: Combine two arrays element-wise into an array of pairs (or merged
 * objects). Use when you have parallel arrays — e.g., a list of header names and
 * a list of values, or matched records from two systems that need to be joined
 * by position.
 *
 * Input (application/json):
 * {
 *   "names": [
 *     "Alice",
 *     "Bob",
 *     "Carol"
 *   ],
 *   "scores": [
 *     92,
 *     87,
 *     95
 *   ]
 * }
 *
 * Output (application/json):
 * [
 * {"productName": "Mechanical Keyboard", "sku": "SKU-100", "price": 149.99, "inStock": true},
 * {"productName": "Wireless Mouse", "sku": "SKU-400", "price": 29.99, "inStock": true},
 * {"productName": "USB-C Hub", "sku": "SKU-300", "price": 49.99, "inStock": false}
 * ]
 */
%dw 2.0
output application/json
var pairs = payload.names zip payload.scores
---
pairs map (pair) -> ({name: pair[0], score: pair[1]})
