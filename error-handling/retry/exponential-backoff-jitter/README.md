## Exponential Backoff with Jitter
> Implement increasing retry delays (1s, 2s, 4s, 8s) with random jitter to avoid thundering herd.

### When to Use
- Calling rate-limited APIs that return 429
- Preventing thundering herd when multiple instances retry simultaneously
- Backend is overloaded and needs progressively longer recovery windows

### Configuration / Code

```xml
<flow name="resilient-api-call">
    <http:listener config-ref="HTTP_Listener" path="/api/data"/>
    <set-variable variableName="retryCount" value="0"/>
    <until-successful maxRetries="4" millisBetweenRetries="1000">
        <set-variable variableName="retryCount" value="#[vars.retryCount + 1]"/>
        <!-- Calculate backoff: baseDelay * 2^attempt + random jitter -->
        <set-variable variableName="backoffMs"
                      value="#[if (vars.retryCount > 1) (1000 * (2 pow (vars.retryCount - 1)) + randomInt(500)) as Number else 0]"/>
        <choice>
            <when expression="#[vars.backoffMs > 0]">
                <scripting:execute engine="groovy">
                    <scripting:code>Thread.sleep(vars.backoffMs.toLong())</scripting:code>
                </scripting:execute>
            </when>
        </choice>
        <http:request config-ref="External_API" path="/data" method="GET"/>
    </until-successful>
    <error-handler>
        <on-error-propagate type="MULE:RETRY_EXHAUSTED">
            <set-variable variableName="httpStatus" value="503"/>
            <set-payload value='{"error":"Service unavailable after exponential backoff"}' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### Backoff Schedule (example)

| Attempt | Base Delay | Jitter (0-500ms) | Total Wait |
|---------|-----------|------------------|------------|
| 1 | 0 ms | 0 | Immediate |
| 2 | 1000 ms | 0-500 ms | 1.0–1.5s |
| 3 | 2000 ms | 0-500 ms | 2.0–2.5s |
| 4 | 4000 ms | 0-500 ms | 4.0–4.5s |
| 5 | 8000 ms | 0-500 ms | 8.0–8.5s |

### How It Works
1. First attempt runs immediately
2. On failure, a variable tracks the retry count
3. Backoff delay doubles each attempt: `baseDelay * 2^attempt`
4. Random jitter (0–500ms) prevents synchronized retries across instances
5. `Thread.sleep()` via Groovy scripting enforces the delay

### Gotchas
- `Thread.sleep()` blocks a thread — use sparingly and only inside until-successful
- Cap the max delay (e.g., 30s) to prevent excessive wait times
- Jitter range should be proportional to load — increase for high-concurrency scenarios
- Consider moving to a circuit breaker if failures persist beyond max retries

### Related
- [Until Successful Basic](../until-successful-basic/) — fixed interval retry
- [Circuit Breaker](../circuit-breaker-object-store/) — stop retrying after threshold
- [HTTP 429 Backoff](../../connector-errors/http-429-backoff/) — using Retry-After header
