## DataWeave Error Object Serialization with Java 17
> Fix DataWeave error object handling and Java exception serialization issues on Java 17

### When to Use
- DataWeave scripts accessing Java exception objects fail on Java 17
- Error handling flows that serialize `error.exception` break after Java upgrade
- Custom error responses that include Java stack trace information

### Configuration / Code

#### 1. Problem: Java Exception Access on Java 17

```dataweave
%dw 2.0
output application/json
---
{
    errorMessage: error.description,
    errorType: error.errorType.identifier,
    // PROBLEM: direct Java exception serialization fails on Java 17
    exception: error.exception,
    stackTrace: error.exception.stackTrace
}
```

#### 2. Safe Error Serialization Pattern

```dataweave
%dw 2.0
output application/json
fun safeErrorResponse(err) = {
    errorMessage: err.description default "Unknown error",
    errorType: err.errorType.identifier default "UNKNOWN",
    cause: err.description default "",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"}
}
---
safeErrorResponse(error)
```

#### 3. Error Handler Configuration

```xml
<error-handler>
    <on-error-continue type="ANY">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    status: "error",
    code: error.errorType.namespace ++ ":" ++ error.errorType.identifier,
    message: error.description default "An error occurred",
    detailedDescription: error.detailedDescription default "",
    failingComponent: error.failingComponent default ""
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </on-error-continue>
</error-handler>
```

#### 4. JVM Flags for Legacy Patterns (Transitional)

```properties
# wrapper.conf
wrapper.java.additional.60=--add-opens=java.base/java.lang=ALL-UNNAMED
wrapper.java.additional.61=--add-opens=java.base/java.lang.reflect=ALL-UNNAMED
wrapper.java.additional.62=--add-opens=java.base/java.io=ALL-UNNAMED
```

#### 5. Custom Error Type Mapping

```dataweave
%dw 2.0
output application/json
var errorMap = {
    "HTTP:CONNECTIVITY": { status: 503, message: "Service unavailable" },
    "HTTP:TIMEOUT": { status: 504, message: "Gateway timeout" },
    "DB:CONNECTIVITY": { status: 503, message: "Database unavailable" },
    "DB:BAD_SQL_SYNTAX": { status: 400, message: "Invalid query" }
}
var errorKey = error.errorType.namespace ++ ":" ++ error.errorType.identifier
var mapped = errorMap[errorKey] default { status: 500, message: "Internal server error" }
---
{ httpStatus: mapped.status, error: mapped.message, correlationId: correlationId }
```

### How It Works
1. Java 17 strong encapsulation prevents reflective access to Java exception internals
2. DataWeave serialization of Java objects relies on reflection — blocked by default in Java 17
3. Safe patterns use only Mule Error API properties (`description`, `errorType`, etc.)
4. The Mule Error API provides all necessary information without Java reflection

### Migration Checklist
- [ ] Search DataWeave scripts for `error.exception` and `error.exception.stackTrace`
- [ ] Replace direct exception access with Mule Error API properties
- [ ] Update error handler transforms to use safe serialization patterns
- [ ] Test error handling flows on Java 17
- [ ] Remove `--add-opens` workarounds after code is updated

### Gotchas
- `error.exception` may return null or throw on Java 17 — always use null-safe operators
- Logger component string conversion of `error.exception` may still work when DW serialization fails
- If using `error.childErrors` in Scatter-Gather, same safe patterns apply to each child error
- Some connectors populate `error.exception` differently — test each error scenario

### Related
- [java11-to-17-encapsulation](../../java-versions/java11-to-17-encapsulation/) — Java 17 encapsulation
- [mule46-to-49](../../runtime-upgrades/mule46-to-49/) — Runtime upgrade context
