# dw-validation-utils

> 12 reusable validation functions for DataWeave 2.x — field validation, pattern matching, and bulk payload validation.

## Installation

```xml
<dependency>
    <groupId>cb0ecddd-1505-4354-870f-45c4217384c2</groupId>
    <artifactId>dw-validation-utils</artifactId>
    <version>1.0.0</version>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::ValidationUtils
output application/json
---
ValidationUtils::validateAll(payload, {
    name: { required: true, minLength: 2, maxLength: 50 },
    email: { required: true, pattern: "^[^@]+@[^@]+\\.[^@]+$" },
    age: { min: 1, max: 150 },
    status: { oneOf: ["ACTIVE", "INACTIVE", "PENDING"] }
})
```

## Function Reference

| Function | Signature | Description |
|----------|-----------|-------------|
| `isRequired` | `(val: Any, fieldName: String) -> Object` | Check if value is non-null and non-empty |
| `minLength` | `(s: String, min: Number, fieldName: String) -> Object` | Validate minimum string length |
| `maxLength` | `(s: String, max: Number, fieldName: String) -> Object` | Validate maximum string length |
| `inRange` | `(n: Number, min: Number, max: Number, fieldName: String) -> Object` | Validate number is within range |
| `matchesPattern` | `(s: String, regex: String, fieldName: String) -> Object` | Validate string matches regex |
| `isValidDate` | `(s: String, fmt: String, fieldName: String) -> Object` | Validate date format |
| `isOneOf` | `(val: Any, allowed: Array, fieldName: String) -> Object` | Validate value is in allowed set |
| `isUUID` | `(s: String) -> Boolean` | Check UUID v4 format |
| `isURL` | `(s: String) -> Boolean` | Check URL format |
| `isPhone` | `(s: String) -> Boolean` | Check E.164 phone format |
| `validateAll` | `(obj: Object, rules: Object) -> Object` | Bulk validate payload against rules |
| `hasRequiredFields` | `(obj: Object, fields: Array<String>) -> Object` | Check all required fields present |

## Validation Result Format

All validation functions return a consistent format:

```json
// Success
{ "valid": true }

// Failure
{ "valid": false, "field": "email", "error": "email is required" }

// validateAll result
{ "valid": false, "errors": [{ "valid": false, "field": "name", "error": "..." }] }
```

## Tests

30 MUnit tests covering all 12 functions including edge cases for date validation, boundary values, and format mismatches.
