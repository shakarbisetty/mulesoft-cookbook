## Circuit Breaker in MuleSoft
> Object Store state machine with trip, reset, and half-open patterns

### When to Use
- Your Mule applications call external services that intermittently fail or slow down
- Cascading failures spread from one slow backend to your entire integration platform
- You need to fail fast instead of waiting for connection timeouts on known-down services
- You want automatic recovery when a failed service comes back online

### The Problem

When a backend service goes down, every request to that service blocks a thread until the connection timeout (default 30 seconds). With 256 threads and a 30-second timeout, just 9 requests per second completely exhaust your thread pool. Every other flow in the application — including flows calling healthy services — starves for threads.

MuleSoft does not provide a built-in circuit breaker component. You must build one using Object Store for state management and a custom flow pattern for the state machine.

### Configuration / Code

#### Circuit Breaker State Machine

```
                  failure_count >= threshold
    ┌──────────┐ ─────────────────────────► ┌──────────┐
    │  CLOSED  │                            │   OPEN   │
    │ (normal) │ ◄──── probe succeeds ───── │ (reject) │
    └──────────┘                            └─────┬────┘
         ▲                                        │
         │              cooldown expires          │
         │                                        ▼
         │           ┌──────────────┐             │
         └───────────│  HALF-OPEN   │◄────────────┘
          success    │ (probe mode) │
                     └──────────────┘
                          │
                     probe fails ──► back to OPEN
```

#### State Definitions

| State | Behavior | Transition |
|-------|----------|------------|
| **CLOSED** | All requests pass through normally | Moves to OPEN when `failure_count >= threshold` within `window` |
| **OPEN** | All requests rejected immediately (no backend call) | Moves to HALF-OPEN after `cooldown_seconds` elapsed |
| **HALF-OPEN** | One probe request allowed through | Success -> CLOSED, Failure -> OPEN |

#### Object Store Schema

```xml
<!-- Circuit breaker state in Object Store -->
<os:object-store name="Circuit_Breaker_Store"
                 persistent="true"
                 entryTtl="86400"
                 entryTtlUnit="SECONDS" />

<!--
  Stored value (JSON):
  {
    "state": "CLOSED|OPEN|HALF_OPEN",
    "failureCount": 0,
    "lastFailureTime": "2026-02-28T10:00:00Z",
    "openedAt": null,
    "cooldownSeconds": 30,
    "failureThreshold": 5,
    "windowSeconds": 60
  }
-->
```

#### Full Circuit Breaker Implementation

```xml
<!-- Subflow: Check circuit breaker state before calling backend -->
<sub-flow name="circuit-breaker-check">
    <!-- Read current state -->
    <try>
        <os:retrieve key="#['cb-' ++ vars.serviceName]"
                     objectStore="Circuit_Breaker_Store" />
        <set-variable variableName="cbState"
                      value="#[read(payload, 'application/json')]" />
    <error-handler>
        <on-error-continue type="OS:KEY_NOT_FOUND">
            <!-- First call — initialize to CLOSED -->
            <set-variable variableName="cbState" value="#[%dw 2.0
output application/java
---
{
    state: 'CLOSED',
    failureCount: 0,
    lastFailureTime: null,
    openedAt: null,
    cooldownSeconds: 30,
    failureThreshold: 5,
    windowSeconds: 60
}]" />
        </on-error-continue>
    </error-handler>
    </try>

    <choice>
        <!-- OPEN: Check if cooldown has expired -->
        <when expression="#[vars.cbState.state == 'OPEN']">
            <choice>
                <when expression="#[
                    (now() as Number { unit: 'seconds' }) -
                    (vars.cbState.openedAt as DateTime as Number { unit: 'seconds' })
                    > vars.cbState.cooldownSeconds
                ]">
                    <!-- Cooldown expired — move to HALF_OPEN -->
                    <set-variable variableName="cbState"
                                  value="#[vars.cbState ++ { state: 'HALF_OPEN' }]" />
                    <flow-ref name="circuit-breaker-save" />
                    <!-- Allow the request through as a probe -->
                </when>
                <otherwise>
                    <!-- Still in cooldown — reject immediately -->
                    <raise-error type="APP:CIRCUIT_OPEN"
                                description="#['Circuit breaker OPEN for ' ++
                                vars.serviceName ++ '. Retry after cooldown.']" />
                </otherwise>
            </choice>
        </when>

        <!-- CLOSED or HALF_OPEN: Allow request through -->
        <otherwise>
            <!-- Request proceeds to backend call -->
        </otherwise>
    </choice>
</sub-flow>

<!-- Subflow: Record success -->
<sub-flow name="circuit-breaker-success">
    <set-variable variableName="cbState" value="#[%dw 2.0
output application/java
---
{
    state: 'CLOSED',
    failureCount: 0,
    lastFailureTime: null,
    openedAt: null,
    cooldownSeconds: vars.cbState.cooldownSeconds,
    failureThreshold: vars.cbState.failureThreshold,
    windowSeconds: vars.cbState.windowSeconds
}]" />
    <flow-ref name="circuit-breaker-save" />
</sub-flow>

<!-- Subflow: Record failure -->
<sub-flow name="circuit-breaker-failure">
    <set-variable variableName="newFailureCount"
                  value="#[vars.cbState.failureCount + 1]" />

    <choice>
        <!-- Threshold breached or was in HALF_OPEN — trip to OPEN -->
        <when expression="#[vars.newFailureCount >= vars.cbState.failureThreshold
                           or vars.cbState.state == 'HALF_OPEN']">
            <set-variable variableName="cbState" value="#[%dw 2.0
output application/java
---
vars.cbState ++ {
    state: 'OPEN',
    failureCount: vars.newFailureCount,
    lastFailureTime: now() as String { format: "yyyy-MM-dd'T'HH:mm:ss'Z'" },
    openedAt: now() as String { format: "yyyy-MM-dd'T'HH:mm:ss'Z'" }
}]" />
            <logger level="WARN"
                    message="#['CIRCUIT BREAKER TRIPPED for ' ++ vars.serviceName ++
                    '. Failures: ' ++ vars.newFailureCount]" />
        </when>
        <otherwise>
            <set-variable variableName="cbState" value="#[%dw 2.0
output application/java
---
vars.cbState ++ {
    failureCount: vars.newFailureCount,
    lastFailureTime: now() as String { format: "yyyy-MM-dd'T'HH:mm:ss'Z'" }
}]" />
        </otherwise>
    </choice>

    <flow-ref name="circuit-breaker-save" />
</sub-flow>

<!-- Subflow: Persist state -->
<sub-flow name="circuit-breaker-save">
    <os:store key="#['cb-' ++ vars.serviceName]"
              objectStore="Circuit_Breaker_Store">
        <os:value>#[write(vars.cbState, 'application/json')]</os:value>
    </os:store>
</sub-flow>
```

#### Using the Circuit Breaker

```xml
<flow name="call-external-service">
    <http:listener config-ref="HTTPS_Listener" path="/api/data" />

    <set-variable variableName="serviceName" value="payment-gateway" />

    <!-- Check circuit state -->
    <flow-ref name="circuit-breaker-check" />

    <!-- Make the actual backend call -->
    <try>
        <http:request config-ref="Payment_Gateway" path="/charge" method="POST"
                     responseTimeout="5000" />

        <!-- Success — record it -->
        <flow-ref name="circuit-breaker-success" />

    <error-handler>
        <on-error-propagate type="HTTP:CONNECTIVITY, HTTP:TIMEOUT">
            <!-- Connectivity failure — record it -->
            <flow-ref name="circuit-breaker-failure" />
            <raise-error type="APP:BACKEND_UNAVAILABLE" />
        </on-error-propagate>
        <on-error-propagate type="HTTP:BAD_REQUEST">
            <!-- 4xx errors are NOT circuit breaker failures -->
            <!-- (the backend is working, the request is bad) -->
        </on-error-propagate>
    </error-handler>
    </try>
</flow>
```

#### Tuning Parameters

| Parameter | Default | Guidance |
|-----------|---------|----------|
| `failureThreshold` | 5 | Lower (3) for critical paths, higher (10) for flaky services |
| `cooldownSeconds` | 30 | Match expected recovery time. Start at 30s, increase if service recovers slowly |
| `windowSeconds` | 60 | Sliding window for failure counting. Shorter = more sensitive |
| `responseTimeout` | 5000ms | Must be < your SLA. A 30s timeout defeats the purpose of circuit breaking |

#### Monitoring Dashboard Metrics

```
Circuit Breaker Health:
┌─────────────────────────────────────────────────────────┐
│ Service             State      Failures  Last Trip      │
│ ─────────────────── ────────── ──────── ─────────────── │
│ payment-gateway     CLOSED     0/5      never           │
│ inventory-service   HALF_OPEN  5/5      2026-02-28 10:15│
│ shipping-api        OPEN       8/5      2026-02-28 10:22│
│ crm-system          CLOSED     2/5      n/a             │
└─────────────────────────────────────────────────────────┘
```

### How It Works

1. **CLOSED state**: All requests pass through. Each failure increments `failureCount`. If `failureCount >= failureThreshold` within `windowSeconds`, transition to OPEN.
2. **OPEN state**: All requests are rejected immediately with `APP:CIRCUIT_OPEN` error. No backend call is made. No thread is blocked. After `cooldownSeconds`, transition to HALF_OPEN.
3. **HALF_OPEN state**: One probe request is allowed through. If it succeeds, reset to CLOSED (failureCount = 0). If it fails, return to OPEN with a fresh cooldown.

### Gotchas

- **Object Store in CloudHub is shared across workers but not instant.** There is a ~100ms propagation delay. Two workers might both send probe requests during HALF_OPEN. Accept this as benign — both probes test the backend, which is fine.
- **Do not count 4xx errors as circuit breaker failures.** A 400 Bad Request means the backend is working; the request is malformed. Only count connectivity errors (timeouts, connection refused, 503) as failures.
- **Set `responseTimeout` aggressively low.** If your SLA is 500ms, set the backend timeout to 3000ms, not 30000ms. A circuit breaker that waits 30 seconds before recording a failure does not protect your thread pool.
- **Persistent Object Store survives redeploys.** If a circuit trips and you fix the backend but redeploy your app, the circuit stays OPEN until cooldown expires. Consider adding a manual reset endpoint for operations.
- **Failure window resets are not automatic.** If you get 4 failures in 55 seconds, then no failures for 10 seconds, the window should reset. The simple implementation above does not do sliding windows — for production, add timestamp-based window logic.

### Related

- [Sync-Async Decision Flowchart](../sync-async-decision-flowchart/) — when async avoids the need for circuit breakers
- [API-Led Performance Patterns](../api-led-performance-patterns/) — caching as an alternative to circuit breaking
- [Multi-Region DR Strategy](../multi-region-dr-strategy/) — failover when circuits trip across regions
- [Rate Limiting Architecture](../rate-limiting-architecture/) — preventing overload before circuits trip
