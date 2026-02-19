%dw 2.0

/**
 * ValidationUtils — Reusable validation functions for DataWeave 2.x
 *
 * Validate incoming data before processing. Each validation function
 * returns an Object with { valid: Boolean, error: String? } for
 * consistent error handling.
 *
 * Usage:
 *   import modules::ValidationUtils
 *   ValidationUtils::isRequired(payload.name, "name")
 *   ValidationUtils::validateAll(payload, validationRules)
 */

/**
 * Check if a value is present (not null, not empty string, not empty array).
 * Returns { valid: true } or { valid: false, field: fieldName, error: "..." }
 */
fun isRequired(val: Any, fieldName: String): Object =
    if (val == null) { valid: false, field: fieldName, error: "$(fieldName) is required" }
    else if (val is String and isEmpty(val as String)) { valid: false, field: fieldName, error: "$(fieldName) must not be empty" }
    else if (val is Array and isEmpty(val as Array)) { valid: false, field: fieldName, error: "$(fieldName) must not be empty" }
    else { valid: true }

/**
 * Validate minimum string length.
 */
fun minLength(s: String, min: Number, fieldName: String = "field"): Object =
    if (sizeOf(s) < min) { valid: false, field: fieldName, error: "$(fieldName) must be at least $(min) characters" }
    else { valid: true }

/**
 * Validate maximum string length.
 */
fun maxLength(s: String, max: Number, fieldName: String = "field"): Object =
    if (sizeOf(s) > max) { valid: false, field: fieldName, error: "$(fieldName) must not exceed $(max) characters" }
    else { valid: true }

/**
 * Validate a number is within a range (inclusive).
 */
fun inRange(n: Number, min: Number, max: Number, fieldName: String = "field"): Object =
    if (n < min or n > max) { valid: false, field: fieldName, error: "$(fieldName) must be between $(min) and $(max)" }
    else { valid: true }

/**
 * Validate a string matches a regex pattern.
 */
fun matchesPattern(s: String, regex: String, fieldName: String = "field"): Object =
    if (s matches (regex as Regex)) { valid: true }
    else { valid: false, field: fieldName, error: "$(fieldName) does not match required pattern" }

/**
 * Validate a string is a parseable date in the given format.
 */
fun isValidDate(s: String, fmt: String, fieldName: String = "field"): Object =
    do {
        var parsed = try(() -> s as Date {format: fmt})
        ---
        if (parsed.success) { valid: true }
        else { valid: false, field: fieldName, error: "$(fieldName) is not a valid date (expected format: $(fmt))" }
    }

/**
 * Validate a value is one of an allowed set.
 */
fun isOneOf(val: Any, allowed: Array, fieldName: String = "field"): Object =
    if (allowed contains val) { valid: true }
    else { valid: false, field: fieldName, error: "$(fieldName) must be one of: $(allowed joinBy ', ')" }

/**
 * Validate a string is a valid UUID (v4 format).
 */
fun isUUID(s: String): Boolean =
    s matches /^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/

/**
 * Validate a string is a valid URL.
 */
fun isURL(s: String): Boolean =
    s matches /^https?:\/\/[^\s\/$.?#].[^\s]*$/

/**
 * Validate a string matches E.164 phone number format.
 */
fun isPhone(s: String): Boolean =
    s matches /^\+?[1-9]\d{1,14}$/

/**
 * Validate an entire payload against a rules object.
 * Rules format: { fieldName: { required: true, minLength: 3, maxLength: 50 } }
 * Returns { valid: Boolean, errors: Array<Object> }
 */
fun validateAll(obj: Object, rules: Object): Object = do {
    var errors = (rules pluck (rule, fieldName) -> do {
        var fieldNameStr = fieldName as String
        var value = obj[fieldNameStr]
        var fieldErrors: Array = (
            (if (rule.required == true)
                [isRequired(value, fieldNameStr)]
            else [])
            ++ (if (rule.minLength != null and value is String)
                [minLength(value as String, rule.minLength as Number, fieldNameStr)]
            else [])
            ++ (if (rule.maxLength != null and value is String)
                [maxLength(value as String, rule.maxLength as Number, fieldNameStr)]
            else [])
            ++ (if (rule.min != null and value is Number)
                [inRange(value as Number, rule.min as Number, rule.max default 999999999, fieldNameStr)]
            else [])
            ++ (if (rule.pattern != null and value is String)
                [matchesPattern(value as String, rule.pattern as String, fieldNameStr)]
            else [])
            ++ (if (rule.oneOf != null)
                [isOneOf(value, rule.oneOf as Array, fieldNameStr)]
            else [])
        ) filter ($.valid == false)
        ---
        fieldErrors
    }) flatMap $
    ---
    {
        valid: isEmpty(errors),
        errors: errors
    }
}

/**
 * Check that an object contains all required fields (non-null).
 */
fun hasRequiredFields(obj: Object, fields: Array<String>): Object = do {
    var missing = fields filter (f) -> obj[f] == null
    ---
    if (isEmpty(missing)) { valid: true, missing: [] }
    else { valid: false, missing: missing, error: "Missing required fields: $(missing joinBy ', ')" }
}
