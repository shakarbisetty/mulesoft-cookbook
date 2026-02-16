/**
 * Pattern: Boolean Handling
 * Category: Type Coercion
 * Difficulty: Beginner
 *
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
 *   "activeAsString": "true",
 *   "activeAsYN": "Y",
 *   "activeAsNumber": 1,
 *   "verifiedAsYN": "N",
 *   "legacyAsBool": true,
 *   "sapAsBool": true,
 *   "numericAsBool": true,
 *   "stringAsBool": true,
 *   "yesNoAsBool": true
 * }
 */
%dw 2.0
output application/json

fun toYN(b: Boolean): String = if (b) "Y" else "N"
fun fromYN(s: String): Boolean = upper(s) == "Y"
fun fromYesNo(s: String): Boolean = upper(s) == "YES"
fun fromSAP(s: String): Boolean = s == "X"
fun toBoolNum(b: Boolean): Number = if (b) 1 else 0
fun fromBoolNum(n: Number): Boolean = n != 0
---
{
    activeAsString: payload.isActive as String,
    activeAsYN: toYN(payload.isActive),
    activeAsNumber: toBoolNum(payload.isActive),
    verifiedAsYN: toYN(payload.isVerified),
    legacyAsBool: fromYN(payload.legacyFlag),
    sapAsBool: fromSAP(payload.sapIndicator),
    numericAsBool: fromBoolNum(payload.numericBool),
    stringAsBool: payload.stringBool as Boolean,
    yesNoAsBool: fromYesNo(payload.yesNoField)
}

// Alternative 1 — inline ternary style:
// if (payload.legacyFlag == "Y") true else false

// Alternative 2 — truthy check for nullable fields:
// payload.someField default false

// Alternative 3 — boolean from string comparison:
// ["Y", "YES", "TRUE", "1", "X"] contains upper(payload.field)
