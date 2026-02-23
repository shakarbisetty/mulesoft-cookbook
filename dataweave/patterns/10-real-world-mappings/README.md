# 10 — Real-World Mappings

Production integration patterns from actual enterprise projects. These aren't toy examples — they demonstrate Salesforce-to-SAP mappings, EDI parsing, SOAP-to-REST conversion, and other patterns you'll encounter in real MuleSoft implementations.

---

## Patterns

| # | Pattern | File | Difficulty | Description |
|---|---------|------|-----------|-------------|
| 1 | Salesforce to SAP | [`salesforce-to-sap.dwl`](salesforce-to-sap.dwl) | Advanced | Map SF Account/Contact to SAP BAPI IDoc |
| 2 | REST API Flattening | [`rest-api-flattening.dwl`](rest-api-flattening.dwl) | Intermediate | Flatten nested API response to flat table |
| 3 | EDI to JSON | [`edi-to-json.dwl`](edi-to-json.dwl) | Advanced | X12 850 Purchase Order to JSON |
| 4 | Batch Payload Split | [`batch-payload-split.dwl`](batch-payload-split.dwl) | Intermediate | Split large arrays into fixed-size batches |
| 5 | SOAP to REST | [`soap-to-rest.dwl`](soap-to-rest.dwl) | Intermediate | SOAP XML envelope to clean REST JSON |
| 6 | Canonical Data Model | [`canonical-data-model.dwl`](canonical-data-model.dwl) | Advanced | Normalize multi-system data to standard format |

---

## When to Use These Patterns

| Scenario | Pattern |
|----------|---------|
| CRM-to-ERP sync | Salesforce to SAP |
| Consuming nested APIs | REST API Flattening |
| B2B/EDI processing | EDI to JSON |
| Bulk API limits | Batch Payload Split |
| Legacy service modernization | SOAP to REST |
| Multi-system hub | Canonical Data Model |

---

## Tips

- **Lookup tables:** Real-world mappings almost always need lookup tables (industry codes, country codes, status mappings). Define them as `var` at the top of your DWL.
- **Default values:** Enterprise data is messy. Always use `default` for optional fields.
- **Type coercion:** Source systems return dates as strings, numbers as strings, booleans as "Y"/"N". Cast explicitly.
- **Test with edge cases:** Empty arrays, null fields, missing optional segments, single vs. multiple repeating elements.
- **Canonical model:** Worth the upfront investment when integrating 3+ systems. Reduces total mapping count from N*M to N+M.

---

[Back to all patterns](../../README.md)
