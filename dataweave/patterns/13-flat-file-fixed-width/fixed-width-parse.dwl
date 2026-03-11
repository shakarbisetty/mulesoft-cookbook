/**
 * Pattern: Fixed-Width Parse
 * Category: Flat File & Fixed-Width
 * Difficulty: Intermediate
 * Description: Parse positional (fixed-width) flat files into structured
 * JSON objects. Each field occupies a fixed number of characters. Common
 * in banking (ACH, BAI), insurance (ACORD), and COBOL mainframe outputs.
 *
 * Input (text/plain):
 * John Smith          28M1990-05-14Austin          TX73301
 * Jane Doe            34F1988-11-22Dallas          TX75201
 * Bob Johnson         45M1979-03-08Houston         TX77001
 *
 * Output (application/json):
 * [
 * {
 * "name": "John Doe",
 * "age": 30,
 * "gender": "M",
 * "dob": "1990-03-15",
 * "city": "San Francisco",
 * "state": "CA",
 * "zip": "95101"
 * },
 * ...
 * ]
 */
%dw 2.0
output application/json
var fieldLayout = [ {name:"name",start:0,length:20}, {name:"age",start:20,length:2}, {name:"gender",start:22,length:1},
    {name:"dob",start:23,length:10}, {name:"city",start:33,length:16}, {name:"state",start:49,length:2}, {name:"zip",start:51,length:5} ]
fun extractField(line, start, length) = trim(line[start to (start + length - 1)])
fun parseLine(line) = fieldLayout reduce (field, acc = {}) -> acc ++ { (field.name): extractField(line, field.start, field.length) }
---
(payload as String splitBy "\n") filter !isEmpty(trim($)) map parseLine($)
