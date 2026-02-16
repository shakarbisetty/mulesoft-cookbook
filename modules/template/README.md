# dw-module-name

> REPLACE with one-line description.

---

## Installation

Add to your Mule project `pom.xml`:

```xml
<dependency>
    <groupId>{ORG_ID}</groupId>
    <artifactId>dw-module-name</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::ModuleName
output application/json
---
ModuleName::functionName("input")
```

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `functionName` | `(s: String) -> String` | REPLACE with description |

## License

[MIT](../../LICENSE)
