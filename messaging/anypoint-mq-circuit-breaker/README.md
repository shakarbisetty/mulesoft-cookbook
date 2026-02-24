## Anypoint MQ Circuit Breaker
> Consumer-side circuit breaker pattern to protect downstream systems during outages

### When to Use
- Your MQ consumer calls a downstream system (database, API, SFTP) that can become unavailable
- You want to stop consuming messages during a downstream outage instead of sending everything to the DLQ
- You need automatic recovery when the downstream system comes back online
- You want to prevent cascade failures where a slow downstream causes consumer backlog, memory pressure, and worker crashes

### Configuration / Code

#### Circuit Breaker with Object Store State

```xml
<!-- Object Store for circuit breaker state -->
<os:object-store name="circuit-breaker-store"
    persistent="true"
    entryTtl="60"
    entryTtlUnit="MINUTES" />

<!-- Circuit breaker configuration properties -->
<!-- In mule-artifact.json or properties file:
    circuit.error.threshold=5
    circuit.half.open.interval=30000
    circuit.success.threshold=3
-->

<!-- Main consumer flow -->
<flow name="mq-consumer-with-circuit-breaker">
    <anypoint-mq:subscriber
        config-ref="Anypoint_MQ_Config"
        destination="orders-queue"
        acknowledgementMode="MANUAL" />

    <!-- Check circuit state -->
    <flow-ref name="check-circuit-state" />

    <choice>
        <!-- OPEN: reject immediately -->
        <when expression="#[vars.circuitState == 'OPEN']">
            <logger level="WARN"
                message="Circuit OPEN — NACKing message #[attributes.messageId] for redelivery" />
            <anypoint-mq:nack />
        </when>

        <!-- CLOSED or HALF_OPEN: attempt processing -->
        <otherwise>
            <try>
                <!-- Call downstream system -->
                <http:request
                    config-ref="Downstream_API_Config"
                    method="POST"
                    path="/api/orders">
                    <http:body>#[payload]</http:body>
                </http:request>

                <!-- Success: record it -->
                <flow-ref name="record-circuit-success" />
                <anypoint-mq:ack />

                <error-handler>
                    <!-- Downstream connectivity errors trigger circuit -->
                    <on-error-propagate
                        type="HTTP:CONNECTIVITY, HTTP:TIMEOUT, HTTP:SERVICE_UNAVAILABLE, MULE:RETRY_EXHAUSTED">
                        <logger level="ERROR"
                            message="Downstream error: #[error.errorType] — #[error.description]" />
                        <flow-ref name="record-circuit-failure" />

                        <!-- NACK for redelivery (message stays in queue) -->
                        <anypoint-mq:nack />
                    </on-error-propagate>

                    <!-- Business errors: don't trip circuit, send to DLQ -->
                    <on-error-propagate type="ANY">
                        <logger level="ERROR"
                            message="Business error (not circuit-tripping): #[error.description]" />
                        <anypoint-mq:nack />
                    </on-error-propagate>
                </error-handler>
            </try>
        </otherwise>
    </choice>
</flow>

<!-- Sub-flow: Check circuit breaker state -->
<sub-flow name="check-circuit-state">
    <try>
        <os:retrieve
            objectStore="circuit-breaker-store"
            key="circuit-state"
            target="circuitState" />

        <error-handler>
            <on-error-continue type="OS:KEY_NOT_FOUND">
                <!-- No state stored = CLOSED (healthy) -->
                <set-variable variableName="circuitState" value="CLOSED" />
            </on-error-continue>
        </error-handler>
    </try>

    <!-- Check if OPEN circuit should transition to HALF_OPEN -->
    <choice>
        <when expression="#[vars.circuitState == 'OPEN']">
            <try>
                <os:retrieve
                    objectStore="circuit-breaker-store"
                    key="circuit-opened-at"
                    target="openedAt" />

                <choice>
                    <when expression="#[(now() as Number - (vars.openedAt as Number)) > p('circuit.half.open.interval') as Number]">
                        <logger level="INFO" message="Circuit transitioning OPEN → HALF_OPEN" />
                        <set-variable variableName="circuitState" value="HALF_OPEN" />
                        <os:store objectStore="circuit-breaker-store" key="circuit-state">
                            <os:value>HALF_OPEN</os:value>
                        </os:store>
                    </when>
                </choice>

                <error-handler>
                    <on-error-continue type="OS:KEY_NOT_FOUND">
                        <set-variable variableName="circuitState" value="CLOSED" />
                    </on-error-continue>
                </error-handler>
            </try>
        </when>
    </choice>
</sub-flow>

<!-- Sub-flow: Record failure and potentially open circuit -->
<sub-flow name="record-circuit-failure">
    <!-- Increment failure counter -->
    <try>
        <os:retrieve objectStore="circuit-breaker-store" key="failure-count" target="failureCount" />
        <error-handler>
            <on-error-continue type="OS:KEY_NOT_FOUND">
                <set-variable variableName="failureCount" value="#[0]" />
            </on-error-continue>
        </error-handler>
    </try>

    <set-variable variableName="failureCount" value="#[vars.failureCount as Number + 1]" />

    <os:store objectStore="circuit-breaker-store" key="failure-count">
        <os:value>#[vars.failureCount as String]</os:value>
    </os:store>

    <!-- Trip circuit if threshold exceeded -->
    <choice>
        <when expression="#[vars.failureCount >= p('circuit.error.threshold') as Number]">
            <logger level="ERROR"
                message="Circuit TRIPPED — #[vars.failureCount] failures exceed threshold #[p('circuit.error.threshold')]" />

            <os:store objectStore="circuit-breaker-store" key="circuit-state">
                <os:value>OPEN</os:value>
            </os:store>
            <os:store objectStore="circuit-breaker-store" key="circuit-opened-at">
                <os:value>#[now() as Number as String]</os:value>
            </os:store>

            <!-- Alert on circuit open -->
            <http:request config-ref="Slack_Webhook_Config" method="POST" path="${slack.webhook.path}">
                <http:body><![CDATA[#[output application/json ---
{
    text: ":rotating_light: *Circuit Breaker OPEN* — downstream failures exceeded threshold (" ++ p('circuit.error.threshold') ++ "). MQ consumption paused."
}]]]></http:body>
            </http:request>
        </when>
    </choice>
</sub-flow>

<!-- Sub-flow: Record success and potentially close circuit -->
<sub-flow name="record-circuit-success">
    <choice>
        <when expression="#[vars.circuitState == 'HALF_OPEN']">
            <!-- Count consecutive successes in HALF_OPEN -->
            <try>
                <os:retrieve objectStore="circuit-breaker-store" key="halfopen-success-count" target="successCount" />
                <error-handler>
                    <on-error-continue type="OS:KEY_NOT_FOUND">
                        <set-variable variableName="successCount" value="#[0]" />
                    </on-error-continue>
                </error-handler>
            </try>

            <set-variable variableName="successCount" value="#[vars.successCount as Number + 1]" />

            <choice>
                <when expression="#[vars.successCount >= p('circuit.success.threshold') as Number]">
                    <logger level="INFO"
                        message="Circuit CLOSING — #[vars.successCount] consecutive successes in HALF_OPEN" />

                    <os:store objectStore="circuit-breaker-store" key="circuit-state">
                        <os:value>CLOSED</os:value>
                    </os:store>
                    <!-- Reset counters -->
                    <os:remove objectStore="circuit-breaker-store" key="failure-count" />
                    <os:remove objectStore="circuit-breaker-store" key="halfopen-success-count" />

                    <http:request config-ref="Slack_Webhook_Config" method="POST" path="${slack.webhook.path}">
                        <http:body><![CDATA[#[output application/json ---
{
    text: ":white_check_mark: *Circuit Breaker CLOSED* — downstream recovered. MQ consumption resumed."
}]]]></http:body>
                    </http:request>
                </when>
                <otherwise>
                    <os:store objectStore="circuit-breaker-store" key="halfopen-success-count">
                        <os:value>#[vars.successCount as String]</os:value>
                    </os:store>
                </otherwise>
            </choice>
        </when>
        <otherwise>
            <!-- CLOSED state: reset failure counter on success -->
            <os:store objectStore="circuit-breaker-store" key="failure-count">
                <os:value>#[0]</os:value>
            </os:store>
        </otherwise>
    </choice>
</sub-flow>
```

#### Circuit Breaker State Diagram

```
                    failure count >= threshold
    ┌────────┐    ──────────────────────────►    ┌────────┐
    │ CLOSED │                                    │  OPEN  │
    │(normal)│    ◄──────────────────────────    │ (stop) │
    └────────┘    N consecutive successes         └────────┘
        ▲          in HALF_OPEN                       │
        │                                             │
        │         ┌───────────┐    timer expires       │
        └─────────│ HALF_OPEN │◄──────────────────────┘
      N successes │  (test 1) │
                  └───────────┘
                        │
                  failure ──► back to OPEN
```

#### Configuration Properties

```yaml
# circuit-breaker.yaml
circuit:
  error:
    threshold: 5          # failures before opening circuit
  half:
    open:
      interval: 30000     # ms before trying HALF_OPEN (30 sec)
  success:
    threshold: 3          # consecutive successes to close circuit

  # Error types that trip the circuit (connectivity only)
  tripping-errors:
    - HTTP:CONNECTIVITY
    - HTTP:TIMEOUT
    - HTTP:SERVICE_UNAVAILABLE
    - DB:CONNECTIVITY
    - MULE:RETRY_EXHAUSTED

  # Error types that do NOT trip the circuit (business errors)
  non-tripping-errors:
    - HTTP:BAD_REQUEST
    - HTTP:UNAUTHORIZED
    - VALIDATION:INVALID_VALUE
```

### How It Works

1. **CLOSED state** (normal operation): The consumer processes messages normally. Every successful call to the downstream resets the failure counter. Every downstream connectivity error increments the failure counter.

2. **Circuit trips to OPEN**: When the failure counter reaches the threshold (e.g., 5 consecutive failures), the circuit opens. In OPEN state, the consumer NACKs every message immediately without calling the downstream. This protects the downstream from additional load during an outage.

3. **NACK during OPEN**: NACKing returns the message to the queue for later redelivery. The message is not lost and does not count toward DLQ maxDeliveries (it's a controlled NACK, not a processing failure).

4. **Timer-based HALF_OPEN**: After the configured interval (e.g., 30 seconds), the circuit transitions to HALF_OPEN. In this state, the consumer processes one message as a test probe.

5. **HALF_OPEN recovery**: If N consecutive messages succeed in HALF_OPEN, the circuit closes and normal processing resumes. If any message fails, the circuit immediately returns to OPEN and the timer resets.

6. **Object Store persistence**: The circuit state is stored in a persistent Object Store, so it survives worker restarts. Without persistence, a restart resets the circuit to CLOSED and immediately hammers the still-down downstream.

7. **Only trip on connectivity errors**: Business errors (400 Bad Request, validation failures) should NOT trip the circuit. These are message-level problems, not downstream outages. Only connectivity errors (timeout, connection refused, 503) indicate a systemic issue.

### Gotchas
- **MQ redelivery during OPEN**: When the circuit is OPEN and you NACK messages, Anypoint MQ redelivers them after the lock TTL expires. If the circuit stays open longer than `maxDeliveries * lockTTL`, messages may exhaust their delivery count and go to the DLQ even though the downstream (not the message) was the problem. Mitigation: set `maxDeliveries` high (e.g., 10+) or extend lock TTL.
- **Subscriber prefetch during circuit OPEN**: Even with the circuit open, the subscriber prefetches messages into the client buffer. With `prefetch="10"`, 10 messages are fetched, NACKed, and refetched in a tight loop. This creates unnecessary load on the MQ broker. Set `prefetch="1"` if circuit breaker is enabled.
- **Multiple workers**: If you have 2+ CloudHub workers, each has its own Object Store instance (unless using a shared OS). Circuit state is per-worker, not global. One worker may have an open circuit while another is still sending traffic. For global circuit state, use an external store (Redis, database).
- **NACK is not free**: Rapid NACK/redeliver cycles consume MQ API calls and count toward your message quota. During a long outage (hours), this can be expensive. Consider adding a sleep/delay before NACKing in OPEN state.
- **Circuit stays open forever**: If the timer or Object Store TTL is misconfigured, the circuit may never transition to HALF_OPEN. Always set an `entryTtl` on the Object Store as a safety net — if the circuit state expires, it defaults to CLOSED.
- **Race condition in HALF_OPEN**: With `maxConcurrency > 1`, multiple messages can enter HALF_OPEN processing simultaneously. The first failure should re-open the circuit, but in-flight messages may still hit the downstream. Use `maxConcurrency="1"` during HALF_OPEN or accept the minor race.

### Related
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) — messages that reach DLQ despite circuit breaker
- [Anypoint MQ FIFO Patterns](../anypoint-mq-fifo-patterns/) — circuit breaker with FIFO ordering
- [VM Queue vs Anypoint MQ](../vm-queue-vs-anypoint-mq/) — VM queues don't have built-in redelivery for circuit breaking
- [Message Ordering Guarantees](../message-ordering-guarantees/) — circuit breaker NACK impact on ordering
