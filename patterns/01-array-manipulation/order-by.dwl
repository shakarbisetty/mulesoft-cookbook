/**
 * Pattern: Order By (Sort Array)
 * Category: Array Manipulation
 * Difficulty: Beginner
 *
 * Description: Sort an array of objects by one or more fields. Use for building
 * sorted API responses, leaderboards, chronological lists, or preparing data
 * for display or downstream processing that requires a specific order.
 *
 * Input (application/json):
 * [
 *   {"sku": "SKU-400", "product": "Wireless Mouse", "price": 29.99, "rating": 4.5},
 *   {"sku": "SKU-100", "product": "Mechanical Keyboard", "price": 149.99, "rating": 4.8},
 *   {"sku": "SKU-300", "product": "USB-C Hub", "price": 49.99, "rating": 4.2},
 *   {"sku": "SKU-200", "product": "Monitor Stand", "price": 79.99, "rating": 4.5},
 *   {"sku": "SKU-500", "product": "Webcam HD", "price": 89.99, "rating": 4.0}
 * ]
 *
 * Output (application/json):
 * [
 *   {"sku": "SKU-400", "product": "Wireless Mouse", "price": 29.99, "rating": 4.5},
 *   {"sku": "SKU-300", "product": "USB-C Hub", "price": 49.99, "rating": 4.2},
 *   {"sku": "SKU-200", "product": "Monitor Stand", "price": 79.99, "rating": 4.5},
 *   {"sku": "SKU-500", "product": "Webcam HD", "price": 89.99, "rating": 4.0},
 *   {"sku": "SKU-100", "product": "Mechanical Keyboard", "price": 149.99, "rating": 4.8}
 * ]
 */
%dw 2.0
output application/json
---
payload orderBy (item) -> item.price

// Alternative 1 — shorthand:
// payload orderBy $.price

// Alternative 2 — descending order (highest first):
// payload orderBy -($.price)

// Alternative 3 — sort by string field (alphabetical):
// payload orderBy $.product

// Alternative 4 — sort by multiple fields (primary + secondary):
// payload orderBy $.rating orderBy $.price
// Note: last orderBy is the primary sort; ties are broken by earlier orderBy
