/**
 * Pattern: Custom Functions
 * Category: Advanced Patterns
 * Difficulty: Advanced
 * Description: Define reusable custom functions with `fun` and lambda
 * expressions. Functions help eliminate repetition, improve readability,
 * and encapsulate complex logic. DataWeave supports named functions,
 * lambdas, default parameters, overloading, and higher-order functions.
 *
 * Input (application/json):
 * {
 *   "products": [
 *     {
 *       "name": "Laptop Pro",
 *       "price": 1299.99
 *     },
 *     {
 *       "name": "Standing Desk",
 *       "price": 799
 *     },
 *     {
 *       "name": "Wireless Mouse",
 *       "price": 29.99
 *     },
 *     {
 *       "name": "Office Chair",
 *       "price": 449
 *     }
 *   ],
 *   "taxRate": 0.0875,
 *   "freeShippingThreshold": 100
 * }
 *
 * Output (application/json):
 * [
 * {"name": "Laptop Pro", "basePrice": 1299.99, "tax": 113.75, "shipping": 0.00, "totalPrice": 1413.74},
 * {"name": "Standing Desk", "basePrice": 799.00, "tax": 69.91, "shipping": 0.00, "totalPrice": 868.91},
 * {"name": "Wireless Mouse", "basePrice": 29.99, "tax": 2.62, "shipping": 5.99, "totalPrice": 38.60},
 * {"name": "Office Chair", "basePrice": 449.00, "tax": 39.29, "shipping": 0.00, "totalPrice": 488.29}
 * ]
 */
%dw 2.0
output application/json
fun roundTo(num: Number, places: Number): Number = (num * pow(10, places) as Number) / pow(10, places)
fun pow(base: Number, exp: Number): Number = if (exp <= 0) 1 else base * pow(base, exp - 1)
fun applyDiscount(price: Number, discountFn: (Number) -> Number): Number = discountFn(price)
var discount = (p: Number) -> if (p > 500) p * 0.9 else p
---
payload.products map (p) -> ({
  name: p.name,
  originalPrice: p.price,
  discounted: roundTo(applyDiscount(p.price, discount), 2),
  tax: roundTo(applyDiscount(p.price, discount) * payload.taxRate, 2),
  freeShipping: p.price >= payload.freeShippingThreshold
})
