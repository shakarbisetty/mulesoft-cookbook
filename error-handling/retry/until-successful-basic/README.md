## Until Successful — Basic Retry
> Wrap a flaky operation in until-successful with fixed interval retries and max attempts.

### When to Use
- Calling an unreliable HTTP endpoint that occasionally times out
- Transient failures that resolve on retry (network blips, temporary 503s)
- Simple retry without exponential backoff complexity

### Configuration / Code

```xml
<flow name="order-sync-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/sync"/>
    <until-successful maxRetries="3" millisBetweenRetries="2000">
        <http:request config-ref="External_API" path="/orders" method="POST">
            <http:response-validator>
                <http:success-status-code-validator values="200..299"/>
            </http:response-validator>
        </http:request>
    </until-successful>
    <set-payload value='{"status":"synced"}' mimeType="application/json"/>
    <error-handler>
        <on-error-propagate type="MULE:RETRY_EXHAUSTED">
            <set-variable variableName="httpStatus" value="502"/>
            <set-payload value='{"error":"External service unavailable after retries"}' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `until-successful` executes the inner block up to `maxRetries` + 1 times (1 attempt + 3 retries)
2. On failure, waits `millisBetweenRetries` (2 seconds) before the next attempt
3. If all retries fail, throws `MULE:RETRY_EXHAUSTED`
4. On success, execution continues after the scope

### Gotchas
- `maxRetries="3"` means 4 total attempts (1 original + 3 retries)
- The retry is NOT idempotent by default — ensure the operation is safe to repeat
- All errors trigger retry by default; use a choice router inside to filter retryable errors
- `millisBetweenRetries` is a fixed delay, not exponential — see exponential backoff recipe for that

### Related
- [Exponential Backoff with Jitter](../exponential-backoff-jitter/) — increasing delays
- [Circuit Breaker](../circuit-breaker-object-store/) — stop retrying after N failures
- [Reconnection Strategy](../reconnection-strategy/) — connector-level retries
