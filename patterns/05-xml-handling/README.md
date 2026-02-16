# 05 — XML Handling

XML remains the backbone of enterprise integration — SOAP services, B2B documents (EDI-XML, OAGIS), HL7, and legacy systems all speak XML. These patterns cover the essential XML operations every MuleSoft developer encounters.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | XML to JSON | [`xml-to-json.dwl`](xml-to-json.dwl) | Intermediate | Convert XML with attributes to clean JSON |
| 2 | JSON to XML | [`json-to-xml.dwl`](json-to-xml.dwl) | Intermediate | Build well-formed XML with elements and attributes |
| 3 | Namespace Handling | [`namespace-handling.dwl`](namespace-handling.dwl) | Advanced | Declare, read, and strip XML namespaces |
| 4 | CDATA Handling | [`cdata-handling.dwl`](cdata-handling.dwl) | Intermediate | Read and write CDATA sections |
| 5 | Attribute Extraction | [`attributes-extraction.dwl`](attributes-extraction.dwl) | Intermediate | Extract XML attributes using `.@` selector |

---

## Core Concepts

| Concept | Syntax | Example |
|---------|--------|---------|
| Read attribute | `.@attrName` | `payload.Order.@id` |
| Read all attributes | `.@` | `payload.Order.@` → `{id: "1", status: "new"}` |
| Set attributes | `@(attr: val)` | `Order @(id: "1"): {...}` |
| Namespace declaration | `ns prefix url` | `ns soap http://...` |
| Namespace access | `prefix#Element` | `payload.soap#Envelope` |
| Repeating elements | `.*Element` | `payload.Items.*Item` |
| CDATA write | `as CData` | `"<html>..." as CData` |

---

## Tips

- **Repeating elements:** Use `.*Element` (not `.Element`) when an element can appear multiple times. Single-element access returns the first match only.
- **Namespace wildcard:** Use `*:ElementName` to match any namespace prefix on an element.
- **Attributes are strings:** XML attributes are always strings. Cast them: `item.@quantity as Number`.
- **Self-closing tags:** Set content to `null` for self-closing: `Contact @(email: "a@b.com"): null` → `<Contact email="a@b.com"/>`.
- **XML output options:** Use `output application/xml indent=true, writeDeclaration=true` for pretty-printed XML with declaration.

---

[Back to all patterns](../../README.md)
