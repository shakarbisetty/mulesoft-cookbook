/**
 * Pattern: Custom Functions
 * Category: Advanced Patterns
 * Difficulty: Advanced
 *
 * Description: Define reusable custom functions with `fun` and lambda
 * expressions. Functions help eliminate repetition, improve readability,
 * and encapsulate complex logic. DataWeave supports named functions,
 * lambdas, default parameters, overloading, and higher-order functions.
 *
 * Input (application/json):
 * {
 *   "products": [
 *     {"name": "Laptop Pro", "basePrice": 1299.99, "category": "electronics", "weight": 2.1},
 *     {"name": "Standing Desk", "basePrice": 799.00, "category": "furniture", "weight": 35.0},
 *     {"name": "Wireless Mouse", "basePrice": 29.99, "category": "electronics", "weight": 0.1},
 *     {"name": "Office Chair", "basePrice": 449.00, "category": "furniture", "weight": 18.5}
 *   ],
 *   "taxRate": 0.0875,
 *   "freeShippingThreshold": 100
 * }
 *
 * Output (application/json):
 * [
 *   {"name": "Laptop Pro", "basePrice": 1299.99, "tax": 113.75, "shipping": 0.00, "totalPrice": 1413.74},
 *   {"name": "Standing Desk", "basePrice": 799.00, "tax": 69.91, "shipping": 0.00, "totalPrice": 868.91},
 *   {"name": "Wireless Mouse", "basePrice": 29.99, "tax": 2.62, "shipping": 5.99, "totalPrice": 38.60},
 *   {"name": "Office Chair", "basePrice": 449.00, "tax": 39.29, "shipping": 0.00, "totalPrice": 488.29}
 * ]
 */
%dw 2.0
output application/json

// Named function with parameters
fun calculateTax(price: Number, rate: Number): Number =
    roundTo(price * rate, 2)

// Function with default parameter
fun calculateShipping(price: Number, weight: Number, freeThreshold: Number = 100): Number =
    if (price >= freeThreshold) 0.00
    else roundTo(5.99 + (weight * 0.50), 2)

// Helper function — multiply, round to integer, then divide back
fun roundTo(num: Number, decimals: Number): Number = do {
    var factor = pow(10, decimals)
    ---
    round(num * factor) / factor
}

// Higher-order function (takes a function as parameter)
fun applyDiscount(price: Number, discountFn: (Number) -> Number): Number =
    discountFn(price)

// Power function
fun pow(base: Number, exp: Number): Number =
    if (exp <= 0) 1
    else base * pow(base, exp - 1)
---
payload.products map (product) -> do {
    var tax = calculateTax(product.basePrice, payload.taxRate)
    var shipping = calculateShipping(product.basePrice, product.weight, payload.freeShippingThreshold)
    ---
    {
        name: product.name,
        basePrice: product.basePrice,
        tax: tax,
        shipping: shipping,
        totalPrice: roundTo(product.basePrice + tax + shipping, 2)
    }
}

// Alternative 1 — lambda (anonymous function) assigned to var:
// var double = (n: Number) -> n * 2
// ---
// [1, 2, 3] map double($)

// Alternative 2 — function overloading (same name, different signatures):
// fun format(d: Date): String = d as String {format: "yyyy-MM-dd"}
// fun format(n: Number): String = n as String {format: "#,##0.00"}

// Alternative 3 — pass functions as arguments:
// var tenPercentOff = (price: Number) -> price * 0.90
// ---
// applyDiscount(100, tenPercentOff)  // Output: 90
