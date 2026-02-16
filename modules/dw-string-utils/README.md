# dw-string-utils

> 15 reusable string utility functions for DataWeave 2.x

---

## Installation

Add to your Mule project `pom.xml`:

```xml
<dependency>
    <groupId>{ORG_ID}</groupId>
    <artifactId>dw-string-utils</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::StringUtils
output application/json
---
{
    camel: StringUtils::camelize("hello_world"),        // "helloWorld"
    snake: StringUtils::snakeCase("helloWorld"),         // "hello_world"
    title: StringUtils::titleCase("hello world"),        // "Hello World"
    slug:  StringUtils::slugify("Hello World!"),         // "hello-world"
    masked: StringUtils::mask("1234567890", 4),          // "******7890"
    padded: StringUtils::padLeft("42", 5, "0"),          // "00042"
    short: StringUtils::truncate("Hello World", 8),      // "Hello..."
    valid: StringUtils::isEmail("user@example.com"),     // true
    blank: StringUtils::isBlank("  "),                   // true
    reversed: StringUtils::reverse("hello"),             // "olleh"
    count: StringUtils::countOccurrences("banana", "an") // 2
}
```

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `camelize` | `(s: String) -> String` | `hello_world` → `helloWorld` |
| `snakeCase` | `(s: String) -> String` | `helloWorld` → `hello_world` |
| `titleCase` | `(s: String) -> String` | `hello world` → `Hello World` |
| `truncate` | `(s: String, len: Number) -> String` | Truncate with `...` ellipsis |
| `padLeft` | `(s: String, len: Number, char: String) -> String` | Left-pad to fixed width |
| `padRight` | `(s: String, len: Number, char: String) -> String` | Right-pad to fixed width |
| `slugify` | `(s: String) -> String` | `Hello World!` → `hello-world` |
| `mask` | `(s: String, visible: Number) -> String` | `1234567890` → `******7890` |
| `isBlank` | `(s: String) -> Boolean` | Null/empty/whitespace check |
| `isEmail` | `(s: String) -> Boolean` | Email format validation |
| `isNumeric` | `(s: String) -> Boolean` | Numeric string check |
| `capitalize` | `(s: String) -> String` | First char uppercase |
| `removeWhitespace` | `(s: String) -> String` | Strip all whitespace |
| `reverse` | `(s: String) -> String` | Reverse characters |
| `countOccurrences` | `(s: String, sub: String) -> Number` | Count substring matches |

## Testing

30 MUnit test cases covering all 15 functions with basic and edge-case inputs.

```bash
mvn clean test
```

## License

[MIT](../../LICENSE)
