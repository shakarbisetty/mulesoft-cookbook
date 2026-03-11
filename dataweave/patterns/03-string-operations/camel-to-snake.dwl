/**
 * Pattern: Case Conversion (camelCase ↔ snake_case)
 * Category: String Operations
 * Difficulty: Intermediate
 * Description: Convert strings between camelCase, snake_case, PascalCase, and
 * kebab-case. Critical when mapping between systems with different naming
 * conventions — e.g., Java/Salesforce camelCase fields to Python/database
 * snake_case columns, or REST API kebab-case to internal camelCase.
 *
 * Input (application/json):
 * {
 *   "camelFields": [
 *     "firstName",
 *     "lastName",
 *     "emailAddress",
 *     "phoneNumber",
 *     "streetAddress"
 *   ],
 *   "snakeFields": [
 *     "first_name",
 *     "last_name",
 *     "email_address",
 *     "phone_number",
 *     "street_address"
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "camelToSnake": ["first_name", "last_name", "email_address", "phone_number", "created_at"],
 * "snakeToCamel": ["firstName", "lastName", "emailAddress", "phoneNumber", "createdAt"],
 * "camelToPascal": ["FirstName", "LastName", "EmailAddress", "PhoneNumber", "CreatedAt"],
 * "camelToKebab": ["first-name", "last-name", "email-address", "phone-number", "created-at"]
 * }
 */
%dw 2.0
output application/json
fun camelToSnake(s) = s replace /([A-Z])/ with ("_" ++ lower($[0]))
fun snakeToCamel(s) = s replace /_([a-z])/ with upper($[1])
---
{toSnake: payload.camelFields map camelToSnake($), toCamel: payload.snakeFields map snakeToCamel($)}
