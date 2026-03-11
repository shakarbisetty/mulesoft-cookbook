/**
 * Pattern: Split and Join
 * Category: String Operations
 * Difficulty: Beginner
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
 * "firstName": "Alice",
 * "middleName": "Marie",
 * "lastName": "Chen",
 * "tagList": ["mulesoft", "dataweave", "integration", "api"],
 * "tagDisplay": "mulesoft | dataweave | integration | api",
 * "fileName": "customer-flow.xml",
 * "fileExtension": "xml"
 * }
 */
%dw 2.0
output application/json
var nameParts = payload.fullName splitBy " "
var tags = payload.tags splitBy ","
var pathParts = payload.filePath splitBy "/"
var fileName = pathParts[-1]
---
{firstName: nameParts[0], middleName: nameParts[1], lastName: nameParts[-1], tagList: tags, tagDisplay: tags joinBy " | ", fileName: fileName, fileExtension: (fileName splitBy ".")[-1]}
