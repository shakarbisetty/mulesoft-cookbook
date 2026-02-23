/**
 * Pattern: Runtime Type Checking and Introspection
 * Category: Advanced Patterns
 * Difficulty: Intermediate
 *
 * Description: Use dw::core::Types to inspect value types at runtime for
 * dynamic transformations. Build generic processors that handle mixed-type
 * inputs, auto-detect payload formats, and apply type-specific logic
 * without hardcoding assumptions.
 *
 * Input (application/json):
 * {
 *   "fields": [
 *     {"key": "name", "value": "Alice Chen"},
 *     {"key": "age", "value": 30},
 *     {"key": "active", "value": true},
 *     {"key": "tags", "value": ["admin", "editor"]},
 *     {"key": "address", "value": {"city": "Portland", "state": "OR"}},
 *     {"key": "score", "value": null}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "schema": [
 *     {"key": "name", "type": "String", "nullable": false, "example": "Alice Chen"},
 *     {"key": "age", "type": "Number", "nullable": false, "example": 30},
 *     {"key": "active", "type": "Boolean", "nullable": false, "example": true},
 *     {"key": "tags", "type": "Array", "nullable": false, "itemCount": 2},
 *     {"key": "address", "type": "Object", "nullable": false, "fieldCount": 2},
 *     {"key": "score", "type": "Null", "nullable": true, "example": null}
 *   ]
 * }
 */
%dw 2.0
output application/json

fun describeType(value) =
    if (value is String) "String"
    else if (value is Number) "Number"
    else if (value is Boolean) "Boolean"
    else if (value is Array) "Array"
    else if (value is Object) "Object"
    else if (value is Null) "Null"
    else "Unknown"
---
{
    schema: payload.fields map (f) -> {
        key: f.key,
        "type": describeType(f.value),
        nullable: f.value is Null,
        (example: f.value) if (f.value is String or f.value is Number or f.value is Boolean or f.value is Null),
        (itemCount: sizeOf(f.value)) if (f.value is Array),
        (fieldCount: sizeOf(f.value)) if (f.value is Object)
    }
}

// Alternative 1 — auto-coerce mixed types to string:
// payload.fields map (f) -> {
//     key: f.key,
//     stringValue: if (f.value is String) f.value
//         else if (f.value is Number) f.value as String
//         else if (f.value is Boolean) f.value as String
//         else if (f.value is Null) ""
//         else write(f.value, "application/json")
// }

// Alternative 2 — dynamic format detection:
// fun detectFormat(raw: String) =
//     if (raw matches /^\s*\{/) "application/json"
//     else if (raw matches /^\s*</) "application/xml"
//     else if (raw contains ",") "application/csv"
//     else "text/plain"
