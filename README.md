# DataWeave Patterns

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![DataWeave 2.x](https://img.shields.io/badge/DataWeave-2.x-blueviolet.svg)](https://docs.mulesoft.com/dataweave/)
[![GitHub Stars](https://img.shields.io/github/stars/shakarbisetty/dataweave-patterns?style=social)](https://github.com/shakarbisetty/dataweave-patterns)
[![80+ Patterns](https://img.shields.io/badge/patterns-80%2B-orange.svg)](#table-of-contents)
[![7 Exchange Modules](https://img.shields.io/badge/Exchange_Modules-7-ff6900.svg)](#anypoint-exchange-modules)

> Production-ready DataWeave 2.x patterns for MuleSoft developers — copy, paste, transform.

---

## Who Is This For?

- **MuleSoft developers** looking for battle-tested DataWeave snippets
- **Integration architects** who need proven transformation patterns for enterprise mappings
- **Teams migrating from DW 1.0 to 2.0** — see our [migration guide](anti-patterns/dw1-vs-dw2-migration.md)
- **Anyone studying for MuleSoft certification** — real-world examples, not toy data

---

## What's Inside

- **80 DataWeave patterns** across 15 categories — each with realistic input/output, working code, and alternative syntax
- **7 Anypoint Exchange modules** with 90+ reusable functions and 170+ MUnit tests
- **[DW 2.x Cheatsheet](cheatsheet/dataweave-2x-cheatsheet.md)** — comprehensive quick-reference ([PDF](cheatsheet/dataweave-2x-cheatsheet.pdf))
- **[Anti-Patterns Guide](anti-patterns/common-mistakes.md)** — 12 common mistakes and how to fix them
- **[DW 1.0 → 2.0 Migration Guide](anti-patterns/dw1-vs-dw2-migration.md)** — comprehensive migration with MEL mapping, MUnit 2, and 40+ expression conversions
- **[MEL to DataWeave Guide](anti-patterns/mel-to-dataweave.md)** — standalone MEL → DW 2.0 reference with 40+ expression mappings
- **[Playground Tips](playground/)** — test any pattern in MuleSoft's online playground

---

## Quick Start

**1. Pick a pattern** from the [table of contents](#table-of-contents) below.

**2. Copy the code** into your Mule project or the [DataWeave Playground](https://developer.mulesoft.com/learn/dataweave/).

**3. Try it** — here's a working example you can paste right now:

```dwl
%dw 2.0
output application/json
---
// Group employees by department, then count per group
payload groupBy $.department
    mapObject ((employees, dept) -> {
        (dept): sizeOf(employees)
    })

// Input:  [{"name":"Alice","department":"Eng"},{"name":"Bob","department":"Sales"},{"name":"Carol","department":"Eng"}]
// Output: {"Eng": 2, "Sales": 1}
```

No install. No dependencies. Just working DataWeave.

---

## Table of Contents

### Patterns by Category

| # | Category | Patterns | Difficulty Range |
|---|----------|----------|-----------------|
| 01 | [Array Manipulation](#01--array-manipulation) | 9 patterns | Beginner → Advanced |
| 02 | [Object Transformation](#02--object-transformation) | 7 patterns | Beginner → Advanced |
| 03 | [String Operations](#03--string-operations) | 5 patterns | Beginner → Intermediate |
| 04 | [Type Coercion](#04--type-coercion) | 4 patterns | Beginner → Advanced |
| 05 | [XML Handling](#05--xml-handling) | 6 patterns | Intermediate → Advanced |
| 06 | [CSV Operations](#06--csv-operations) | 4 patterns | Beginner → Intermediate |
| 07 | [Error Handling](#07--error-handling) | 5 patterns | Beginner → Intermediate |
| 08 | [Date/Time](#08--datetime) | 4 patterns | Beginner → Intermediate |
| 09 | [Advanced Patterns](#09--advanced-patterns) | 6 patterns | Advanced |
| 10 | [Real-World Mappings](#10--real-world-mappings) | 6 patterns | Intermediate → Advanced |
| 11 | [Security & Encoding](#11--security--encoding) | 6 patterns | Intermediate → Advanced |
| 12 | [API Response Patterns](#12--api-response-patterns) | 5 patterns | Intermediate → Advanced |
| 13 | [Flat File / Fixed Width](#13--flat-file--fixed-width) | 4 patterns | Intermediate → Advanced |
| 14 | [Lookup & Enrichment](#14--lookup--enrichment) | 4 patterns | Intermediate → Advanced |
| 15 | [Performance Optimization](#15--performance-optimization) | 5 patterns | Advanced |

---

### 01 — Array Manipulation

| Pattern | File | Difficulty |
|---------|------|-----------|
| Filter by Condition | [`filter-by-condition.dwl`](patterns/01-array-manipulation/filter-by-condition.dwl) | Beginner |
| Map Transform | [`map-transform.dwl`](patterns/01-array-manipulation/map-transform.dwl) | Beginner |
| Flatten Nested Arrays | [`flatten-nested.dwl`](patterns/01-array-manipulation/flatten-nested.dwl) | Intermediate |
| Group by Field | [`group-by-field.dwl`](patterns/01-array-manipulation/group-by-field.dwl) | Intermediate |
| Distinct Values | [`distinct-by.dwl`](patterns/01-array-manipulation/distinct-by.dwl) | Intermediate |
| Order/Sort | [`order-by.dwl`](patterns/01-array-manipulation/order-by.dwl) | Beginner |
| Reduce/Accumulate | [`reduce-accumulate.dwl`](patterns/01-array-manipulation/reduce-accumulate.dwl) | Advanced |
| Zip Arrays | [`zip-arrays.dwl`](patterns/01-array-manipulation/zip-arrays.dwl) | Intermediate |
| Sliding Window | [`sliding-window.dwl`](patterns/01-array-manipulation/sliding-window.dwl) | Advanced |

### 02 — Object Transformation

| Pattern | File | Difficulty |
|---------|------|-----------|
| Rename Keys | [`rename-keys.dwl`](patterns/02-object-transformation/rename-keys.dwl) | Beginner |
| Remove Keys | [`remove-keys.dwl`](patterns/02-object-transformation/remove-keys.dwl) | Beginner |
| Merge Objects | [`merge-objects.dwl`](patterns/02-object-transformation/merge-objects.dwl) | Intermediate |
| Pluck Values | [`pluck-values.dwl`](patterns/02-object-transformation/pluck-values.dwl) | Intermediate |
| Dynamic Keys | [`dynamic-keys.dwl`](patterns/02-object-transformation/dynamic-keys.dwl) | Advanced |
| Nested Object Update | [`nested-object-update.dwl`](patterns/02-object-transformation/nested-object-update.dwl) | Advanced |
| Object to Pairs | [`object-to-pairs.dwl`](patterns/02-object-transformation/object-to-pairs.dwl) | Intermediate |

### 03 — String Operations

| Pattern | File | Difficulty |
|---------|------|-----------|
| Split and Join | [`split-join.dwl`](patterns/03-string-operations/split-join.dwl) | Beginner |
| Regex Match/Replace | [`regex-match-replace.dwl`](patterns/03-string-operations/regex-match-replace.dwl) | Intermediate |
| Case Conversion | [`camel-to-snake.dwl`](patterns/03-string-operations/camel-to-snake.dwl) | Intermediate |
| Template Strings | [`template-strings.dwl`](patterns/03-string-operations/template-strings.dwl) | Beginner |
| String Padding | [`string-padding.dwl`](patterns/03-string-operations/string-padding.dwl) | Intermediate |

### 04 — Type Coercion

| Pattern | File | Difficulty |
|---------|------|-----------|
| String to Date | [`string-to-date.dwl`](patterns/04-type-coercion/string-to-date.dwl) | Intermediate |
| Number Formatting | [`number-formatting.dwl`](patterns/04-type-coercion/number-formatting.dwl) | Beginner |
| Boolean Handling | [`boolean-handling.dwl`](patterns/04-type-coercion/boolean-handling.dwl) | Beginner |
| Custom Types | [`custom-types.dwl`](patterns/04-type-coercion/custom-types.dwl) | Advanced |

### 05 — XML Handling

| Pattern | File | Difficulty |
|---------|------|-----------|
| XML to JSON | [`xml-to-json.dwl`](patterns/05-xml-handling/xml-to-json.dwl) | Intermediate |
| JSON to XML | [`json-to-xml.dwl`](patterns/05-xml-handling/json-to-xml.dwl) | Intermediate |
| Namespace Handling | [`namespace-handling.dwl`](patterns/05-xml-handling/namespace-handling.dwl) | Advanced |
| CDATA Handling | [`cdata-handling.dwl`](patterns/05-xml-handling/cdata-handling.dwl) | Intermediate |
| Attribute Extraction | [`attributes-extraction.dwl`](patterns/05-xml-handling/attributes-extraction.dwl) | Intermediate |
| SOAP Envelope Builder | [`soap-envelope-builder.dwl`](patterns/05-xml-handling/soap-envelope-builder.dwl) | Advanced |

### 06 — CSV Operations

| Pattern | File | Difficulty |
|---------|------|-----------|
| CSV to JSON | [`csv-to-json.dwl`](patterns/06-csv-operations/csv-to-json.dwl) | Beginner |
| JSON to CSV | [`json-to-csv.dwl`](patterns/06-csv-operations/json-to-csv.dwl) | Beginner |
| Custom Separator | [`custom-separator.dwl`](patterns/06-csv-operations/custom-separator.dwl) | Intermediate |
| Multiline CSV | [`multiline-csv.dwl`](patterns/06-csv-operations/multiline-csv.dwl) | Intermediate |

### 07 — Error Handling

| Pattern | File | Difficulty |
|---------|------|-----------|
| Default Values | [`default-values.dwl`](patterns/07-error-handling/default-values.dwl) | Beginner |
| Try Pattern | [`try-pattern.dwl`](patterns/07-error-handling/try-pattern.dwl) | Intermediate |
| Error Response Builder | [`error-response-builder.dwl`](patterns/07-error-handling/error-response-builder.dwl) | Intermediate |
| Conditional Error | [`conditional-error.dwl`](patterns/07-error-handling/conditional-error.dwl) | Intermediate |
| Retry Backoff Config | [`retry-backoff-config.dwl`](patterns/07-error-handling/retry-backoff-config.dwl) | Advanced |

### 08 — Date/Time

| Pattern | File | Difficulty |
|---------|------|-----------|
| Date Formatting | [`date-formatting.dwl`](patterns/08-date-time/date-formatting.dwl) | Beginner |
| Timezone Conversion | [`timezone-conversion.dwl`](patterns/08-date-time/timezone-conversion.dwl) | Intermediate |
| Date Arithmetic | [`date-arithmetic.dwl`](patterns/08-date-time/date-arithmetic.dwl) | Intermediate |
| Epoch Conversion | [`epoch-conversion.dwl`](patterns/08-date-time/epoch-conversion.dwl) | Intermediate |

### 09 — Advanced Patterns

| Pattern | File | Difficulty |
|---------|------|-----------|
| Recursive Transform | [`recursive-transform.dwl`](patterns/09-advanced-patterns/recursive-transform.dwl) | Advanced |
| Custom Functions | [`custom-functions.dwl`](patterns/09-advanced-patterns/custom-functions.dwl) | Advanced |
| Multi-Level GroupBy | [`multi-level-groupby.dwl`](patterns/09-advanced-patterns/multi-level-groupby.dwl) | Advanced |
| Dynamic Schema | [`dynamic-schema.dwl`](patterns/09-advanced-patterns/dynamic-schema.dwl) | Advanced |
| Tail Recursion | [`tail-recursion.dwl`](patterns/09-advanced-patterns/tail-recursion.dwl) | Advanced |
| Pattern Matching | [`pattern-matching.dwl`](patterns/09-advanced-patterns/pattern-matching.dwl) | Advanced |

### 10 — Real-World Mappings

| Pattern | File | Difficulty |
|---------|------|-----------|
| Salesforce to SAP | [`salesforce-to-sap.dwl`](patterns/10-real-world-mappings/salesforce-to-sap.dwl) | Advanced |
| REST API Flattening | [`rest-api-flattening.dwl`](patterns/10-real-world-mappings/rest-api-flattening.dwl) | Intermediate |
| EDI to JSON | [`edi-to-json.dwl`](patterns/10-real-world-mappings/edi-to-json.dwl) | Advanced |
| Batch Payload Split | [`batch-payload-split.dwl`](patterns/10-real-world-mappings/batch-payload-split.dwl) | Intermediate |
| SOAP to REST | [`soap-to-rest.dwl`](patterns/10-real-world-mappings/soap-to-rest.dwl) | Intermediate |
| Canonical Data Model | [`canonical-data-model.dwl`](patterns/10-real-world-mappings/canonical-data-model.dwl) | Advanced |

### 11 — Security & Encoding

| Pattern | File | Difficulty |
|---------|------|-----------|
| Base64 Encoding | [`base64-encoding.dwl`](patterns/11-security-encoding/base64-encoding.dwl) | Intermediate |
| JWT Decode | [`jwt-decode.dwl`](patterns/11-security-encoding/jwt-decode.dwl) | Advanced |
| URL Encoding | [`url-encoding.dwl`](patterns/11-security-encoding/url-encoding.dwl) | Intermediate |
| Data Masking | [`data-masking.dwl`](patterns/11-security-encoding/data-masking.dwl) | Intermediate |
| HMAC Signature | [`hmac-signature.dwl`](patterns/11-security-encoding/hmac-signature.dwl) | Advanced |
| XML Signature Prep | [`xml-signature-prep.dwl`](patterns/11-security-encoding/xml-signature-prep.dwl) | Advanced |

### 12 — API Response Patterns

| Pattern | File | Difficulty |
|---------|------|-----------|
| Pagination Response | [`pagination-response.dwl`](patterns/12-api-response-patterns/pagination-response.dwl) | Intermediate |
| Error Envelope (RFC 7807) | [`error-envelope.dwl`](patterns/12-api-response-patterns/error-envelope.dwl) | Intermediate |
| HATEOAS Links | [`hateoas-links.dwl`](patterns/12-api-response-patterns/hateoas-links.dwl) | Advanced |
| Bulk Response Builder | [`bulk-response-builder.dwl`](patterns/12-api-response-patterns/bulk-response-builder.dwl) | Advanced |
| Response Filtering | [`response-filtering.dwl`](patterns/12-api-response-patterns/response-filtering.dwl) | Intermediate |

### 13 — Flat File / Fixed Width

| Pattern | File | Difficulty |
|---------|------|-----------|
| Fixed Width Parse | [`fixed-width-parse.dwl`](patterns/13-flat-file-fixed-width/fixed-width-parse.dwl) | Intermediate |
| Fixed Width Generate | [`fixed-width-generate.dwl`](patterns/13-flat-file-fixed-width/fixed-width-generate.dwl) | Intermediate |
| Multi-Record Flat File | [`multi-record-flatfile.dwl`](patterns/13-flat-file-fixed-width/multi-record-flatfile.dwl) | Advanced |
| Flat File to JSON | [`flatfile-to-json.dwl`](patterns/13-flat-file-fixed-width/flatfile-to-json.dwl) | Advanced |

### 14 — Lookup & Enrichment

| Pattern | File | Difficulty |
|---------|------|-----------|
| Lookup Table Join | [`lookup-table-join.dwl`](patterns/14-lookup-enrichment/lookup-table-join.dwl) | Intermediate |
| Conditional Enrichment | [`conditional-enrichment.dwl`](patterns/14-lookup-enrichment/conditional-enrichment.dwl) | Intermediate |
| Cross-Reference Mapping | [`cross-reference-mapping.dwl`](patterns/14-lookup-enrichment/cross-reference-mapping.dwl) | Advanced |
| Hierarchical Lookup | [`hierarchical-lookup.dwl`](patterns/14-lookup-enrichment/hierarchical-lookup.dwl) | Advanced |

### 15 — Performance Optimization

| Pattern | File | Difficulty |
|---------|------|-----------|
| Lazy Evaluation | [`lazy-evaluation.dwl`](patterns/15-performance-optimization/lazy-evaluation.dwl) | Advanced |
| Streaming Reduce | [`streaming-reduce.dwl`](patterns/15-performance-optimization/streaming-reduce.dwl) | Advanced |
| Index-Based Lookup | [`index-based-lookup.dwl`](patterns/15-performance-optimization/index-based-lookup.dwl) | Intermediate |
| Selective Transform | [`selective-transform.dwl`](patterns/15-performance-optimization/selective-transform.dwl) | Advanced |
| Parallel-Safe Chunking | [`parallel-safe-chunking.dwl`](patterns/15-performance-optimization/parallel-safe-chunking.dwl) | Advanced |

---

### References

- [DW 2.x Cheatsheet](cheatsheet/dataweave-2x-cheatsheet.md) | [PDF download](cheatsheet/dataweave-2x-cheatsheet.pdf)
- [Anti-Patterns & Common Mistakes](anti-patterns/common-mistakes.md)
- [DW 1.0 → 2.0 Migration Guide](anti-patterns/dw1-vs-dw2-migration.md)
- [MEL to DataWeave Guide](anti-patterns/mel-to-dataweave.md)
- [Playground Tips](playground/)

---

## Anypoint Exchange Modules

Reusable DataWeave utility libraries — import via Maven, no copy-paste needed.

| Module | Functions | Tests | Description |
|--------|-----------|-------|-------------|
| [`dw-string-utils`](modules/dw-string-utils/) | 19 | 37 | String utilities (camelize, slugify, mask, substringBefore, initials, etc.) |
| [`dw-date-utils`](modules/dw-date-utils/) | 14 | 32 | Date/time utilities (addDays, diffDays, toBusinessDay, quarter, etc.) |
| [`dw-collection-utils`](modules/dw-collection-utils/) | 19 | 29 | Collection utilities (chunk, deepMerge, sliding, zip, transpose, etc.) |
| [`dw-error-handler`](modules/dw-error-handler/) | 10 | 26 | Error handling (classifyError, isRetryable, toRFC7807, errorChain, etc.) |
| [`dw-xml-helpers`](modules/dw-xml-helpers/) | 12 | 24 | XML utilities (stripNamespaces, xpathLike, soapEnvelope, xmlToString, etc.) |
| [`dw-validation-utils`](modules/dw-validation-utils/) | 12 | 24 | Validation (isRequired, matchesPattern, validateAll, isUUID, etc.) |
| [`dw-api-utils`](modules/dw-api-utils/) | 10 | 22 | API response helpers (paginate, buildLinks, filterFields, addETag, etc.) |

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on adding patterns, submitting PRs, and code style requirements.

---

## License

[MIT](LICENSE) — Copyright (c) 2026 Shakar Bisetty

---

Built by [WeavePilot](https://github.com/shakarbisetty/dataweave-patterns) — curated DataWeave patterns for the MuleSoft community.
