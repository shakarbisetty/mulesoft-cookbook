## Common Error Messages Decoded
> Top 30 Mule error messages with actual root causes and immediate fixes — the 3AM reference guide

### When to Use
- You hit an error in production and need to know what it actually means right now
- The error message from Mule doesn't clearly explain the root cause
- You need to quickly distinguish between a config problem and an infrastructure problem
- New team member is unfamiliar with Mule error taxonomy

### How Mule Error Types Work

Mule errors follow the `NAMESPACE:TYPE` format:
- **NAMESPACE** = the module/connector that raised the error (e.g., `HTTP`, `DB`, `MULE`, `APIKIT`)
- **TYPE** = the specific error category (e.g., `CONNECTIVITY`, `TIMEOUT`, `BAD_REQUEST`)

Error hierarchy: `MULE:ANY` → `MULE:CONNECTIVITY` → `HTTP:CONNECTIVITY`. More specific types inherit from general ones. Your error handlers match from most-specific to least-specific.

```xml
<!-- This catches HTTP:CONNECTIVITY but NOT DB:CONNECTIVITY -->
<on-error-continue type="HTTP:CONNECTIVITY">

<!-- This catches ALL connectivity errors from any connector -->
<on-error-continue type="MULE:CONNECTIVITY">

<!-- This catches literally everything -->
<on-error-continue type="MULE:ANY">
```

### Diagnosis Steps

#### The Error Reference Table

| # | Error Message | Root Cause | Quick Fix |
|---|---------------|-----------|-----------|
| 1 | `MULE:CONNECTIVITY — Connection refused` | Target host is down or port is wrong | Verify host:port is reachable: `curl -v http://host:port/health` |
| 2 | `MULE:CONNECTIVITY — Connection timed out` | Network path blocked (firewall, security group, private space rules) | Check firewall rules, VPC peering, private space network config |
| 3 | `MULE:TIMEOUT` | Operation exceeded configured timeout | Increase `responseTimeout` on the connector, or fix the slow downstream |
| 4 | `MULE:EXPRESSION — Script 'payload.field' has an error: Cannot coerce Null to Object` | Payload is null when you try to access a field | Add null check: `payload.field default ""` or check `payload != null` |
| 5 | `MULE:EXPRESSION — Unable to resolve reference of component` | Referencing a bean or global element that doesn't exist | Check `name` attribute matches the `ref`, verify the config file is loaded |
| 6 | `MULE:ROUTING — No route found` | Choice router has no matching condition and no default route | Add `<otherwise>` block to your `<choice>` router |
| 7 | `MULE:SECURITY — Authentication failed` | Invalid credentials or expired token | Verify credentials in properties file, check token expiry, rotate secrets |
| 8 | `MULE:SECURITY — Unauthorized` | The authenticated principal lacks required permissions | Check RBAC policies, API policies on the target, OAuth scopes |
| 9 | `MULE:RETRY_EXHAUSTED` | All retry attempts failed — wraps the original error | Fix the underlying error (check the `cause` in the error object) |
| 10 | `MULE:COMPOSITE_ROUTING` | Multiple routes in scatter-gather or parallel-foreach failed | Inspect `error.errorMessage.payload` — it's a list of individual errors |
| 11 | `HTTP:UNAUTHORIZED (401)` | Missing or invalid authentication credentials sent to external API | Check `Authorization` header, API key, or OAuth token |
| 12 | `HTTP:FORBIDDEN (403)` | Credentials are valid but insufficient permissions | Verify API permissions, check IP allowlists, review API policies |
| 13 | `HTTP:NOT_FOUND (404)` | Endpoint path doesn't exist on the target | Verify URL path, check API version in basePath, look for typos |
| 14 | `HTTP:METHOD_NOT_ALLOWED (405)` | Using GET where POST is expected (or vice versa) | Match the HTTP method to what the target API expects |
| 15 | `HTTP:TOO_MANY_REQUESTS (429)` | Rate limit exceeded on external API | Implement backoff: wait for `Retry-After` header value, then retry |
| 16 | `HTTP:INTERNAL_SERVER_ERROR (500)` | Target API has a bug or is overloaded | Not your code's fault — add retry with backoff, alert the target team |
| 17 | `HTTP:SERVICE_UNAVAILABLE (503)` | Target is in maintenance or overloaded | Retry with exponential backoff, check target status page |
| 18 | `HTTP:TIMEOUT` | HTTP request exceeded `responseTimeout` | Increase timeout or optimize the target; default is 10000ms |
| 19 | `APIKIT:BAD_REQUEST` | Incoming request doesn't match the RAML/OAS spec | Check request body, headers, query params against your API spec |
| 20 | `APIKIT:NOT_FOUND` | Incoming request path doesn't match any RAML resource | Verify the resource path in your RAML/OAS, check basePath |
| 21 | `APIKIT:METHOD_NOT_ALLOWED` | HTTP method not defined for this resource in the spec | Add the method to your RAML/OAS or fix the client request |
| 22 | `APIKIT:NOT_ACCEPTABLE` | Client `Accept` header doesn't match any response mediaType | Add the media type to your RAML response definition |
| 23 | `DB:CONNECTIVITY` | Can't connect to database — wrong host, port, credentials, or DB is down | Test connection: `mysql -h host -P port -u user -p`, check JDBC URL |
| 24 | `DB:QUERY_EXECUTION` | SQL error — bad syntax, missing table, constraint violation | Check SQL in DB client first; look for the actual SQL error in the nested cause |
| 25 | `DB:BAD_SQL_SYNTAX` | Malformed SQL statement | Copy the SQL from debug logs, run it directly in your DB client |
| 26 | `SFTP:CONNECTIVITY` | Can't connect to SFTP server | Verify host, port 22, credentials, SSH key format; `sftp user@host` to test |
| 27 | `SFTP:FILE_NOT_FOUND` | File doesn't exist at the specified path | Check path is absolute, verify filename and case sensitivity |
| 28 | `JMS:ACK — Failed to acknowledge message` | Message acknowledgment failed, possibly due to session/connection drop | Check broker connection stability, verify ack mode configuration |
| 29 | `ANYPOINT-MQ:ACKING — Failed to acknowledge` | Anypoint MQ message lock expired before processing completed | Increase `acknowledgementTimeout` (default 2min), optimize processing time |
| 30 | `MULE:UNKNOWN` | Error doesn't map to any known type | Check the full stack trace — the actual cause is in `error.cause.message` |

#### How to Get More Detail from Any Error

```dataweave
%dw 2.0
output application/json
---
{
  errorType: error.errorType.namespace ++ ":" ++ error.errorType.identifier,
  errorMessage: error.description,
  detailedMessage: error.detailedDescription,
  cause: error.cause.message default "none",
  causeClass: error.cause.class default "none",
  childErrors: error.childErrors map {
    errorType: $.errorType.namespace ++ ":" ++ $.errorType.identifier,
    message: $.description
  }
}
```

### How It Works
1. When an exception occurs in a connector or processor, it's mapped to a Mule error type
2. The error type follows the `NAMESPACE:TYPE` hierarchy rooted at `MULE:ANY`
3. Error handlers (`on-error-continue`, `on-error-propagate`) match against these types
4. Unhandled errors propagate up the flow chain until caught or reaching the default handler
5. The `error` object in DataWeave contains: `description`, `detailedDescription`, `errorType`, `cause`, `childErrors`

### Gotchas
- **Custom error types mask real errors** — if you `raise:` a custom error type in your error handler, downstream handlers see only your custom type, not the original. Always log the original error before raising.
- **Error handler ordering matters** — handlers are evaluated top-to-bottom; put specific types (`HTTP:TIMEOUT`) before general types (`MULE:ANY`). A `MULE:ANY` handler at the top will catch everything and skip your specific handlers.
- **`on-error-continue` vs `on-error-propagate`** — `continue` swallows the error and the flow returns a success response. `propagate` re-throws it. Using `continue` when you meant `propagate` will return 200 OK to clients when something actually failed.
- **`MULE:COMPOSITE_ROUTING`** is NOT a single error — it wraps multiple errors from parallel execution. You must iterate `error.errorMessage.payload` to see each individual failure.
- **`HTTP:INTERNAL_SERVER_ERROR` from your own API** means your flow threw an unhandled error — check your error handlers, not the "target API"
- **Error types are case-sensitive** — `HTTP:TIMEOUT` works, `http:timeout` does not
- **Some connectors use generic `MULE:CONNECTIVITY`** instead of their own namespace — always check `error.cause` for the real details

### Related
- [Thread Dump Analysis](../thread-dump-analysis/) — when error messages aren't appearing but the app is stuck
- [Deployment Failure Flowchart](../deployment-failure-flowchart/) — when the error happens during deployment, not runtime
- [Connection Pool Exhaustion Diagnosis](../connection-pool-exhaustion-diagnosis/) — when you see repeated CONNECTIVITY or TIMEOUT errors
- [Error Type Mapping](../../error-handling/http-errors/error-type-mapping/) — designing error mapping for your APIs
