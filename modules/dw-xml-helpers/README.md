# dw-xml-helpers

> 10 reusable XML utility functions for DataWeave 2.x

---

## Installation

Add to your Mule project `pom.xml`:

```xml
<dependency>
    <groupId>{ORG_ID}</groupId>
    <artifactId>dw-xml-helpers</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::XmlHelpers
output application/json

var soapResponse = {"soap:Envelope": {"soap:Body": {"ns1:GetPriceResponse": {"ns1:Price": "29.99"}}}}
---
{
    // Strip namespace prefixes for clean access
    clean: XmlHelpers::stripNamespaces(soapResponse),

    // XPath-like selection
    price: XmlHelpers::xpathLike(
        XmlHelpers::stripNamespaces(soapResponse),
        "Envelope.Body.GetPriceResponse.Price"
    ),

    // Flatten to dot-notation
    flat: XmlHelpers::xmlToFlat({order: {id: "123", item: "Widget"}}, "."),

    // Validate structure
    check: XmlHelpers::validateStructure(
        {name: "Alice", age: 30},
        {name: "String", age: "Number", email: "String"}
    )
}
```

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `nsAware` | `(xml: Object, nsUri: String, prefix: String) -> Object` | Apply namespace prefix to element keys |
| `stripNamespaces` | `(xml: Object) -> Object` | Remove all namespace prefixes recursively |
| `extractAttributes` | `(xml: Object, elem: String) -> Object` | Get `@` attributes from a named element |
| `cdataWrap` | `(value: String) -> String` | Wrap string as CDATA for XML output |
| `cdataUnwrap` | `(cdata: Any) -> String` | Extract string content from CDATA |
| `xmlToFlat` | `(xml: Object, sep: String) -> Object` | Flatten nested XML to dot-notation keys |
| `flatToXml` | `(obj: Object, sep: String) -> Object` | Dot-notation keys back to nested structure |
| `mergeXmlNodes` | `(a: Object, b: Object) -> Object` | Deep merge two XML trees |
| `xpathLike` | `(xml: Any, path: String) -> Any` | Simple dot-delimited path selector |
| `validateStructure` | `(xml: Object, schema: Object) -> Object` | Validate keys against expected schema |

## Testing

20 MUnit test cases covering all 10 functions with nested XML structures, namespace stripping, path selection, merge conflicts, and structural validation.

```bash
mvn clean test
```

## License

[MIT](../../LICENSE)
