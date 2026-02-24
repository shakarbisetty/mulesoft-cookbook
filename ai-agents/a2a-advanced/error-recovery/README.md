## A2A Error Recovery
> Handle agent failures with retry logic, fallback agents, and graceful degradation.

### When to Use
- Production agent workflows where reliability is critical
- Agents with intermittent failures (LLM rate limits, network issues)
- Multi-agent pipelines where one failure should not break everything

### Configuration / Code

```xml
<flow name="resilient-agent-call">
    <http:listener config-ref="HTTP_Listener" path="/resilient-task" method="POST"/>
    <until-successful maxRetries="3" millisBetweenRetries="2000">
        <try>
            <http:request config-ref="Primary_Agent" path="/a2a/tasks/send" method="POST"
                          responseTimeout="30000"/>
            <error-handler>
                <on-error-continue type="HTTP:TIMEOUT">
                    <logger message="Primary agent timeout, attempt #[vars.counter]"/>
                    <raise-error type="RETRY"/>
                </on-error-continue>
            </error-handler>
        </try>
    </until-successful>
    <error-handler>
        <on-error-continue type="MULE:RETRY_EXHAUSTED">
            <logger message="Primary agent failed, falling back to secondary"/>
            <http:request config-ref="Fallback_Agent" path="/a2a/tasks/send" method="POST"/>
        </on-error-continue>
    </error-handler>
</flow>
```

### How It Works
1. Primary agent is called with retry logic (3 attempts, 2s delay)
2. Timeouts and transient errors trigger retries
3. After retry exhaustion, a fallback agent handles the task
4. All failures are logged for operational visibility

### Gotchas
- Idempotency is critical — retried tasks must not cause duplicate actions
- Fallback agents may produce different quality results — document the trade-off
- Timeout values should be longer than the agent average response time
- Circuit breaker pattern is better than retries for sustained failures

### Related
- [Multi-Agent Orchestration](../multi-agent-orchestration/) — orchestration patterns
- [Circuit Breaker](../../error-handling/retry/circuit-breaker-object-store/) — circuit breaker pattern
