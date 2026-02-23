/**
 * Pattern: Split and Join
 * Category: String Operations
 * Difficulty: Beginner
 *
 * Description: Split a string into an array by a delimiter, and join an array
 * back into a string. Fundamental for parsing CSV-like values, breaking apart
 * compound identifiers, building comma-separated lists, and reformatting
 * delimited data between systems.
 *
 * Input (application/json):
 * {
 *   "fullName": "Alice Marie Chen",
 *   "tags": "mulesoft,dataweave,integration,api",
 *   "filePath": "/opt/mule/apps/customer-api/src/main/mule/customer-flow.xml"
 * }
 *
 * Output (application/json):
 * {
 *   "firstName": "Alice",
 *   "middleName": "Marie",
 *   "lastName": "Chen",
 *   "tagList": ["mulesoft", "dataweave", "integration", "api"],
 *   "tagDisplay": "mulesoft | dataweave | integration | api",
 *   "fileName": "customer-flow.xml",
 *   "fileExtension": "xml"
 * }
 */
%dw 2.0
output application/json
var nameParts = payload.fullName splitBy " "
var tags = payload.tags splitBy ","
var pathParts = payload.filePath splitBy "/"
var fileName = pathParts[-1]
---
{
    firstName: nameParts[0],
    middleName: nameParts[1],
    lastName: nameParts[-1],
    tagList: tags,
    tagDisplay: tags joinBy " | ",
    fileName: fileName,
    fileExtension: (fileName splitBy ".")[-1]
}

// Alternative 1 — split by regex pattern:
// "2026-01-15T10:30:00Z" splitBy /[-T:Z]/
// Output: ["2026", "01", "15", "10", "30", "00", ""]

// Alternative 2 — join with custom separator:
// ["San Francisco", "CA", "94102"] joinBy ", "
// Output: "San Francisco, CA, 94102"

// Alternative 3 — split and trim whitespace:
// " alice , bob , carol " splitBy "," map trim($)
// Output: ["alice", "bob", "carol"]
