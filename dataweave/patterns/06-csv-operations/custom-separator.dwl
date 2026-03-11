/**
 * Pattern: Custom Separator (Delimiter)
 * Category: CSV Operations
 * Difficulty: Intermediate
 * Description: Handle CSV-like files with non-standard delimiters — tabs (TSV),
 * pipes, semicolons, or other characters. Many enterprise systems and EDI
 * formats use pipe-delimited or tab-delimited files instead of commas.
 * Configure the separator in the input/output MIME type properties.
 *
 * Input (text/plain):
 * productId|productName|category|price|inStock
 * PRD-001|Ergonomic Keyboard|Electronics|89.99|true
 * PRD-002|Standing Desk Mat|Furniture|34.50|true
 * PRD-003|USB-C Hub|Electronics|45.00|false
 * PRD-004|Monitor Arm|Furniture|129.99|true
 *
 * Output (application/json):
 * [
 * {"productId": "PRD-001", "productName": "Mechanical Keyboard", "category": "Electronics", "price": 149.99, "inStock": true},
 * {"productId": "PRD-002", "productName": "Standing Desk", "category": "Furniture", "price": 799.00, "inStock": true},
 * {"productId": "PRD-003", "productName": "Noise-Canceling Headset", "category": "Electronics", "price": 299.95, "inStock": false},
 * {"productId": "PRD-004", "productName": "Ergonomic Mouse", "category": "Electronics", "price": 79.99, "inStock": true}
 * ]
 */
%dw 2.0
output application/json
input payload application/csv separator = "|"
---
payload map (row) -> ({
  productId: row.productId,
  productName: row.productName,
  category: row.category,
  price: row.price as Number,
  inStock: row.inStock as Boolean
})
