/**
 * Pattern: Boolean Handling
 * Category: Type Coercion
 * Difficulty: Beginner
 * Description: Convert between boolean values and their string/number
 * representations. Different systems represent booleans differently —
 * true/false, "Y"/"N", 1/0, "yes"/"no", "true"/"false", "T"/"F". This
 * pattern covers all common conversions.
 *
 * Input (application/json):
 * {
 *   "isActive": true,
 *   "isVerified": false,
 *   "legacyFlag": "Y",
 *   "sapIndicator": "X",
 *   "numericBool": 1,
 *   "stringBool": "true",
 *   "yesNoField": "yes"
 * }
 *
 * Output (application/json):
 * {
 * "activeAsString": "true",
 * "activeAsYN": "Y",
 * "activeAsNumber": 1,
 * "verifiedAsYN": "N",
 * "legacyAsBool": true,
 * "sapAsBool": true,
 * "numericAsBool": true,
 * "stringAsBool": true,
 * "yesNoAsBool": true
 * }
 */
%dw 2.0
output application/json
fun toBoolean(val) = val match {case is Boolean -> val case "Y" -> true case "N" -> false case "X" -> true case "" -> false case "yes" -> true case "no" -> false case is Number -> val != 0 case is String -> val as Boolean}
---
{isActive: toBoolean(payload.isActive), isVerified: toBoolean(payload.isVerified), legacyFlag: toBoolean(payload.legacyFlag), sapIndicator: toBoolean(payload.sapIndicator), numericBool: toBoolean(payload.numericBool), stringBool: toBoolean(payload.stringBool), yesNoField: toBoolean(payload.yesNoField)}
