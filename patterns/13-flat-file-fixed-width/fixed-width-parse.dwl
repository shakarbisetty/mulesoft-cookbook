/**
 * Pattern: Fixed-Width Parse
 * Category: Flat File & Fixed-Width
 * Difficulty: Intermediate
 *
 * Description: Parse positional (fixed-width) flat files into structured
 * JSON objects. Each field occupies a fixed number of characters. Common
 * in banking (ACH, BAI), insurance (ACORD), and COBOL mainframe outputs.
 *
 * Input (text/plain):
 * John Doe          30M1990-03-15San Francisco   CA95101
 * Jane Smith        25F1998-07-22New York        NY10001
 * Bob Johnson       45M1980-11-30Chicago         IL60601
 *
 * Field layout:
 *   Name:     positions 0-19  (20 chars)
 *   Age:      positions 20-21 (2 chars)
 *   Gender:   position  22    (1 char)
 *   DOB:      positions 23-32 (10 chars)
 *   City:     positions 33-48 (16 chars)
 *   State:    positions 49-50 (2 chars)
 *   Zip:      positions 51-55 (5 chars)
 *
 * Output (application/json):
 * [
 *   {
 *     "name": "John Doe",
 *     "age": 30,
 *     "gender": "M",
 *     "dob": "1990-03-15",
 *     "city": "San Francisco",
 *     "state": "CA",
 *     "zip": "95101"
 *   },
 *   ...
 * ]
 */
%dw 2.0
output application/json

// Define the field layout: [name, start, length]
var fieldLayout = [
    { name: "name",   start: 0,  length: 20 },
    { name: "age",    start: 20, length: 2 },
    { name: "gender", start: 22, length: 1 },
    { name: "dob",    start: 23, length: 10 },
    { name: "city",   start: 33, length: 16 },
    { name: "state",  start: 49, length: 2 },
    { name: "zip",    start: 51, length: 5 }
]

// Extract a field from a fixed-width line
fun extractField(line: String, start: Number, length: Number): String =
    trim(line[start to (start + length - 1)])

// Parse a single line using the layout
fun parseLine(line: String): Object =
    fieldLayout reduce (field, acc = {}) ->
        acc ++ { (field.name): extractField(line, field.start, field.length) }
---
(payload as String splitBy "\n")
    filter !isEmpty(trim($))
    map (line) -> do {
        var parsed = parseLine(line)
        ---
        parsed ++ {
            age: parsed.age as Number
        }
    }

// Alternative — using MuleSoft's Flat File connector:
// If you have a .ffd schema file, MuleSoft can parse flat files natively
// with: input application/flatfile schemaPath="myschema.ffd"
