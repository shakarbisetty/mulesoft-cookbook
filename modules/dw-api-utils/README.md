# dw-api-utils

> 10 reusable API response helper functions for DataWeave 2.x — pagination, error envelopes, field filtering, sorting, and query string handling.

## Installation

```xml
<dependency>
    <groupId>cb0ecddd-1505-4354-870f-45c4217384c2</groupId>
    <artifactId>dw-api-utils</artifactId>
    <version>1.0.0</version>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::ApiUtils
output application/json
---
{
    response: ApiUtils::paginate(payload.customers, 1, 10),
    links: ApiUtils::buildLinks("/api/customers", 1, 5, 10)
}
```

## Function Reference

| Function | Signature | Description |
|----------|-----------|-------------|
| `paginate` | `(arr: Array, page: Number, size: Number) -> Object` | Build paginated response with metadata (page, totalPages, hasNext, hasPrevious) |
| `buildLinks` | `(basePath: String, page: Number, totalPages: Number, pageSize: Number) -> Object` | Generate pagination navigation links (self, first, last, next, previous) |
| `filterFields` | `(obj: Object, fields: Array<String>) -> Object` | Filter object to only include specified fields; supports dot notation |
| `sortBy` | `(arr: Array, field: String, order: String = "asc") -> Array` | Sort array of objects by field name with asc/desc direction |
| `buildSuccessResponse` | `(data: Any, meta: Object = {}) -> Object` | Wrap data in a standard success response envelope |
| `buildErrorResponse` | `(status: Number, title: String, detail: String) -> Object` | Build an RFC 7807 Problem Details error response |
| `addETag` | `(data: Any) -> String` | Generate a quoted MD5 ETag hash from a payload for cache validation |
| `buildBulkResult` | `(results: Array<Object>) -> Object` | Summarize bulk operation results with success/failure counts |
| `toQueryString` | `(params: Object) -> String` | Convert an object to a URL query string |
| `fromQueryString` | `(qs: String) -> Object` | Parse a URL query string into an object |

## Response Formats

### Paginated Response
```json
{
  "data": [{ "id": 1 }, { "id": 2 }],
  "meta": {
    "page": 1,
    "pageSize": 10,
    "totalRecords": 50,
    "totalPages": 5,
    "hasNext": true,
    "hasPrevious": false
  }
}
```

### Error Response (RFC 7807)
```json
{
  "type": "about:blank",
  "title": "Not Found",
  "status": 404,
  "detail": "Customer CUST-001 not found"
}
```

### Bulk Result
```json
{
  "summary": { "total": 3, "successful": 2, "failed": 1 },
  "errors": [{ "id": "3", "error": "Duplicate key" }]
}
```

## Tests

22 MUnit tests covering all 10 functions.
