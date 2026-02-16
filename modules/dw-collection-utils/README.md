# dw-collection-utils

> 15 reusable array and object utility functions for DataWeave 2.x

---

## Installation

Add to your Mule project `pom.xml`:

```xml
<dependency>
    <groupId>{ORG_ID}</groupId>
    <artifactId>dw-collection-utils</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::CollectionUtils
output application/json
---
{
    chunked: CollectionUtils::chunk([1,2,3,4,5], 2),              // [[1,2],[3,4],[5]]
    cleaned: CollectionUtils::compact([1, null, 2, "", 3]),        // [1,2,3]
    common: CollectionUtils::intersection([1,2,3], [2,3,4]),       // [2,3]
    diff: CollectionUtils::difference([1,2,3,4], [2,4]),           // [1,3]
    combined: CollectionUtils::union([1,2,3], [3,4,5]),            // [1,2,3,4,5]
    selected: CollectionUtils::pick({a:1, b:2, c:3}, ["a","c"]),   // {a:1, c:3}
    removed: CollectionUtils::omit({a:1, b:2, c:3}, ["b"]),       // {a:1, c:3}
    merged: CollectionUtils::deepMerge({x:{a:1}}, {x:{b:2}}),     // {x:{a:1, b:2}}
    flat: CollectionUtils::flattenKeys({a:{b:1}}, "."),            // {"a.b":1}
    deduped: CollectionUtils::unique([1,2,2,3,3]),                 // [1,2,3]
    split: CollectionUtils::partition([1,2,3,4], (n) -> mod(n,2)==0), // {pass:[2,4], fail:[1,3]}
    indexed: CollectionUtils::indexBy([{id:"a",v:1}], "id"),       // {a:{id:"a",v:1}}
    counted: CollectionUtils::countBy([1,2,3], (n) -> if (mod(n,2)==0) "even" else "odd")
}
```

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `chunk` | `(arr: Array, size: Number) -> Array<Array>` | Split array into chunks |
| `compact` | `(arr: Array) -> Array` | Remove null and empty values |
| `intersection` | `(a: Array, b: Array) -> Array` | Common elements |
| `difference` | `(a: Array, b: Array) -> Array` | Elements in a, not in b |
| `union` | `(a: Array, b: Array) -> Array` | Combine and deduplicate |
| `pick` | `(obj: Object, keys: Array<String>) -> Object` | Select keys |
| `omit` | `(obj: Object, keys: Array<String>) -> Object` | Remove keys |
| `deepMerge` | `(a: Object, b: Object) -> Object` | Recursive merge |
| `pivot` | `(arr: Array<Object>) -> Object` | Rows to columns |
| `unpivot` | `(obj: Object) -> Array<Object>` | Columns to rows |
| `flattenKeys` | `(obj: Object, sep: String) -> Object` | Nested to dot-notation keys |
| `unique` | `(arr: Array) -> Array` | Remove duplicates |
| `partition` | `(arr: Array, fn: Function) -> Object` | Split by predicate (pass/fail) |
| `indexBy` | `(arr: Array<Object>, key: String) -> Object` | Array to keyed lookup |
| `countBy` | `(arr: Array, fn: Function) -> Object` | Group and count |

## Testing

25 MUnit test cases covering all 15 functions with basic, edge, and boundary inputs.

```bash
mvn clean test
```

## License

[MIT](../../LICENSE)
