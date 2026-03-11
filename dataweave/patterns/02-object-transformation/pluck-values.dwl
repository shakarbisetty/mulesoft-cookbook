/**
 * Pattern: Pluck Values
 * Category: Object Transformation
 * Difficulty: Intermediate
 * Description: Extract keys, values, or key-value pairs from an object into an
 * array. Use pluck when you need to iterate over an object's entries (like
 * Object.entries() in JavaScript). Common for building dropdown options from
 * config objects, converting objects to arrays for further processing, or
 * extracting all values for aggregation.
 *
 * Input (application/json):
 * {
 *   "productPrices": {
 *     "Laptop": 1299.99,
 *     "Monitor": 599.99,
 *     "Keyboard": 149.99,
 *     "Mouse": 29.99,
 *     "Headset": 199.95
 *   }
 * }
 *
 * Output (application/json):
 * [
 * {"product": "Laptop", "price": 1299.99},
 * {"product": "Monitor", "price": 599.99},
 * {"product": "Keyboard", "price": 149.99},
 * {"product": "Mouse", "price": 29.99},
 * {"product": "Headset", "price": 199.95}
 * ]
 */
%dw 2.0
output application/json
---
payload.productPrices pluck (price, product) -> ({product: product as String, price: price})
