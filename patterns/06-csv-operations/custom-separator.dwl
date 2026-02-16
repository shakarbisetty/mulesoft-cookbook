/**
 * Pattern: Custom Separator (Delimiter)
 * Category: CSV Operations
 * Difficulty: Intermediate
 *
 * Description: Handle CSV-like files with non-standard delimiters — tabs (TSV),
 * pipes, semicolons, or other characters. Many enterprise systems and EDI
 * formats use pipe-delimited or tab-delimited files instead of commas.
 * Configure the separator in the input/output MIME type properties.
 *
 * Input (application/csv, separator="|"):
 * productId|productName|category|price|inStock
 * PRD-001|Mechanical Keyboard|Electronics|149.99|true
 * PRD-002|Standing Desk|Furniture|799.00|true
 * PRD-003|Noise-Canceling Headset|Electronics|299.95|false
 * PRD-004|Ergonomic Mouse|Electronics|79.99|true
 *
 * Output (application/json):
 * [
 *   {"productId": "PRD-001", "productName": "Mechanical Keyboard", "category": "Electronics", "price": 149.99, "inStock": true},
 *   {"productId": "PRD-002", "productName": "Standing Desk", "category": "Furniture", "price": 799.00, "inStock": true},
 *   {"productId": "PRD-003", "productName": "Noise-Canceling Headset", "category": "Electronics", "price": 299.95, "inStock": false},
 *   {"productId": "PRD-004", "productName": "Ergonomic Mouse", "category": "Electronics", "price": 79.99, "inStock": true}
 * ]
 */
%dw 2.0
input payload application/csv separator="|"
output application/json
---
payload map (row) -> {
    productId: row.productId,
    productName: row.productName,
    category: row.category,
    price: row.price as Number,
    inStock: row.inStock as Boolean
}

// Alternative 1 — tab-separated (TSV):
// input payload application/csv separator="\t"

// Alternative 2 — semicolon-separated (common in European locales):
// input payload application/csv separator=";"

// Alternative 3 — output as pipe-delimited:
// output application/csv separator="|", quoteValues=true
// ---
// payload

// Alternative 4 — full CSV reader config:
// input payload application/csv separator="|", header=true, quoteChar="\"", escapeChar="\\"
