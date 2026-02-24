## HTTP 429 Rate Limit Backoff
> Detect HTTP 429 Too Many Requests, extract the Retry-After header, wait, and retry.

### When to Use
- Calling rate-limited APIs (Salesforce, Stripe, cloud services)
- The API returns `Retry-After` header with wait time
- You want automatic compliance with rate limits

### Configuration / Code

```xml
<flow name="rate-limited-api-call">
    <http:listener config-ref="HTTP_Listener" path="/api/sync"/>
    <set-variable variableName="maxAttempts" value="3"/>
    <set-variable variableName="attempt" value="0"/>

    <until-successful maxRetries="#[vars.maxAttempts]" millisBetweenRetries="1000">
        <set-variable variableName="attempt" value="#[vars.attempt + 1]"/>
        <try>
            <http:request config-ref="External_API" path="/data" method="GET"/>
            <error-handler>
                <on-error-continue type="HTTP:TOO_MANY_REQUESTS">
                    <set-variable variableName="retryAfter"
                                  value="#[error.errorMessage.attributes.headers.'retry-after' default '5']"/>
                    <logger level="WARN" message="Rate limited. Retry-After: #[vars.retryAfter]s (attempt #[vars.attempt])"/>
                    <scripting:execute engine="groovy">
                        <scripting:code>Thread.sleep((vars.retryAfter as Long) * 1000)</scripting:code>
                    </scripting:execute>
                    <raise-error type="APP:RATE_LIMITED" description="Rate limited, retrying"/>
                </on-error-continue>
            </error-handler>
        </try>
    </until-successful>
</flow>
```

### How It Works
1. On 429 response, extract `Retry-After` header (seconds to wait)
2. Sleep for the specified duration
3. Raise a custom error to trigger the until-successful retry
4. After max attempts, `MULE:RETRY_EXHAUSTED` is thrown

### Gotchas
- `Retry-After` can be seconds (integer) or an HTTP-date — handle both formats
- `Thread.sleep()` blocks a thread; for high concurrency, consider queueing instead
- Some APIs return 429 without `Retry-After` — always have a default wait time
- Rate limits may be per-client, per-IP, or global — check the API documentation

### Related
- [Exponential Backoff](../../retry/exponential-backoff-jitter/) — general backoff strategy
- [Rate Limit Sliding Window](../../performance/api-performance/rate-limit-sliding-window/) — applying your own rate limits
