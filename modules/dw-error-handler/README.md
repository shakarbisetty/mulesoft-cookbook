# dw-error-handler

> 8 reusable error handling utility functions for DataWeave 2.x

---

## Installation

Add to your Mule project `pom.xml`:

```xml
<dependency>
    <groupId>cb0ecddd-1505-4354-870f-45c4217384c2</groupId>
    <artifactId>dw-error-handler</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

## Usage

```dwl
%dw 2.0
import modules::ErrorHandler
output application/json

var err = {errorType: {identifier: "HTTP:TIMEOUT"}, description: "Request timed out"}
var category = ErrorHandler::classifyError(err)
---
{
    response: ErrorHandler::buildErrorResponse(
        ErrorHandler::httpStatusFromError(category),
        category,
        err.description
    ),
    retryable: ErrorHandler::isRetryable(err),
    logLine: ErrorHandler::errorToLog(err)
}

// Output:
// {
//   "response": {"error": {"code": 408, "message": "TIMEOUT", "detail": "Request timed out", "timestamp": "..."}},
//   "retryable": true,
//   "logLine": "ERROR [HTTP:TIMEOUT] Request timed out"
// }
```

## Functions

| Function | Signature | Description |
|----------|-----------|-------------|
| `buildErrorResponse` | `(code: Number, msg: String, detail: String) -> Object` | Standardized JSON error with timestamp |
| `classifyError` | `(error: Object) -> String` | Categorize error (VALIDATION, AUTHENTICATION, TIMEOUT, etc.) |
| `isRetryable` | `(error: Object) -> Boolean` | Whether error is transient/retryable |
| `errorToLog` | `(error: Object) -> String` | Sanitized single-line log string |
| `sanitizeError` | `(error: Object) -> Object` | Strip stackTrace, exception, cause from error |
| `wrapWithCorrelation` | `(error: Object, correlationId: String) -> Object` | Add correlation ID for distributed tracing |
| `httpStatusFromError` | `(errorType: String) -> Number` | Map error category to HTTP status code |
| `buildFaultResponse` | `(code: String, msg: String) -> Object` | SOAP fault response with timestamp |

### Error Classification Map

| Error Identifier Contains | Category | HTTP Status |
|--------------------------|----------|-------------|
| VALIDATION, BAD_REQUEST, EXPRESSION | VALIDATION | 400 |
| UNAUTHORIZED, UNAUTHENTICATED | AUTHENTICATION | 401 |
| FORBIDDEN, ACCESS_DENIED | AUTHORIZATION | 403 |
| NOT_FOUND | NOT_FOUND | 404 |
| TIMEOUT | TIMEOUT | 408 |
| CONNECTIVITY, CONNECTION_REFUSED | CONNECTIVITY | 503 |
| TRANSFORMATION, MAPPING | TRANSFORMATION | 500 |
| (anything else) | SYSTEM | 500 |

### Retryable Errors

Timeout, connectivity, connection refused, retry exhausted, and HTTP status codes 429, 502, 503, 504.

## Testing

22 MUnit test cases covering all 8 functions with standard Mule error structures, edge cases, and missing fields.

```bash
mvn clean test
```

## License

[MIT](../../LICENSE)
