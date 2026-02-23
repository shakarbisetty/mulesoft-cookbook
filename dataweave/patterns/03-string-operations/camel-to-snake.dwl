/**
 * Pattern: Case Conversion (camelCase ↔ snake_case)
 * Category: String Operations
 * Difficulty: Intermediate
 *
 * Description: Convert strings between camelCase, snake_case, PascalCase, and
 * kebab-case. Critical when mapping between systems with different naming
 * conventions — e.g., Java/Salesforce camelCase fields to Python/database
 * snake_case columns, or REST API kebab-case to internal camelCase.
 *
 * Input (application/json):
 * {
 *   "camelFields": ["firstName", "lastName", "emailAddress", "phoneNumber", "createdAt"],
 *   "snakeFields": ["first_name", "last_name", "email_address", "phone_number", "created_at"]
 * }
 *
 * Output (application/json):
 * {
 *   "camelToSnake": ["first_name", "last_name", "email_address", "phone_number", "created_at"],
 *   "snakeToCamel": ["firstName", "lastName", "emailAddress", "phoneNumber", "createdAt"],
 *   "camelToPascal": ["FirstName", "LastName", "EmailAddress", "PhoneNumber", "CreatedAt"],
 *   "camelToKebab": ["first-name", "last-name", "email-address", "phone-number", "created-at"]
 * }
 */
%dw 2.0
output application/json

fun camelToSnake(s: String): String =
    s replace /([A-Z])/ with ("_" ++ lower($[0]))

fun snakeToCamel(s: String): String =
    s replace /_(\w)/ with upper($[1])

fun camelToPascal(s: String): String =
    upper(s[0]) ++ s[1 to -1]

fun camelToKebab(s: String): String =
    s replace /([A-Z])/ with ("-" ++ lower($[0]))
---
{
    camelToSnake: payload.camelFields map camelToSnake($),
    snakeToCamel: payload.snakeFields map snakeToCamel($),
    camelToPascal: payload.camelFields map camelToPascal($),
    camelToKebab: payload.camelFields map camelToKebab($)
}

// Alternative 1 — using DW built-in camelize / underscore (Strings module):
// import * from dw::core::Strings
// ---
// {
//     camelized: camelize("first_name"),      // "firstName"
//     underscored: underscore("firstName")     // "first_name"
// }

// Alternative 2 — convert all keys in an object:
// payload mapObject (value, key) ->
//     {(camelToSnake(key as String)): value}
