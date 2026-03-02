# INVALID_SESSION_ID Root Cause Analysis and Recovery

## Problem

`INVALID_SESSION_ID` is the most common Salesforce connector error in MuleSoft production deployments, yet its root cause varies widely. The same error code is returned for five completely different failure scenarios: expired OAuth tokens, sandbox refresh invalidating credentials, IP range restrictions blocking the MuleSoft worker, concurrent authentication session limits, and manually revoked tokens. Teams waste hours debugging because they treat all `INVALID_SESSION_ID` errors identically, applying token refresh when the real issue is an IP restriction that no amount of re-authentication will fix.

## Solution

Implement a diagnostic flow that identifies the specific root cause of `INVALID_SESSION_ID` errors, applies the correct recovery action for each cause, uses exponential backoff to prevent infinite retry loops, and alerts operations when automatic recovery is not possible. Include a decision tree that classifies the failure before attempting any recovery.

## Implementation

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Recovery configuration -->
    <global-property name="sf.recovery.maxAttempts" value="5"/>
    <global-property name="sf.recovery.initialBackoffMs" value="2000"/>
    <global-property name="sf.recovery.maxBackoffMs" value="60000"/>

    <!-- Recovery state tracking -->
    <os:object-store name="sessionRecoveryStore"
                     persistent="true"
                     entryTtl="1"
                     entryTtlUnit="HOURS"/>

    <!-- Error handler: attach to any flow that calls Salesforce -->
    <sub-flow name="sf-operation-with-recovery">
        <try>
            <!-- Your Salesforce operation goes here -->
            <flow-ref name="execute-sf-operation"/>

            <!-- On success, reset recovery counter -->
            <os:store key="recoveryAttempts"
                      objectStore="sessionRecoveryStore">
                <os:value>#[0]</os:value>
            </os:store>

            <error-handler>
                <!-- Catch INVALID_SESSION_ID specifically -->
                <on-error-continue
                    type="SALESFORCE:INVALID_SESSION
                          OR SALESFORCE:CONNECTIVITY
                          OR HTTP:UNAUTHORIZED">

                    <flow-ref name="diagnose-and-recover"/>
                </on-error-continue>
            </error-handler>
        </try>
    </sub-flow>

    <!-- Diagnostic and recovery flow -->
    <sub-flow name="diagnose-and-recover">
        <!-- Track recovery attempts -->
        <os:retrieve key="recoveryAttempts"
                     objectStore="sessionRecoveryStore"
                     target="attempts">
            <os:default-value>#[0]</os:default-value>
        </os:retrieve>

        <set-variable variableName="attemptCount"
                      value="#[(vars.attempts as Number) + 1]"/>

        <!-- Circuit breaker: stop retrying after max attempts -->
        <choice>
            <when expression="#[vars.attemptCount > Mule::p('sf.recovery.maxAttempts') as Number]">
                <logger level="ERROR"
                        message='Session recovery exhausted after #[vars.attemptCount - 1] attempts. Alerting operations.'/>
                <flow-ref name="alert-operations-team"/>
                <raise-error type="APP:SESSION_RECOVERY_EXHAUSTED"
                             description="All automatic session recovery attempts failed"/>
            </when>
        </choice>

        <!-- Store attempt count -->
        <os:store key="recoveryAttempts"
                  objectStore="sessionRecoveryStore">
            <os:value>#[vars.attemptCount]</os:value>
        </os:store>

        <!-- Step 1: Diagnose the root cause -->
        <ee:transform doc:name="Classify Error Root Cause">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var errorMsg = error.description default ""
var errorDetail = error.detailedDescription default ""
var combined = lower(errorMsg ++ " " ++ errorDetail)

// Root cause classification based on error message patterns
var rootCause =
    if (combined contains "ip" and combined contains "restrict")
        "IP_RESTRICTION"
    else if (combined contains "refresh" and combined contains "sandbox")
        "SANDBOX_REFRESH"
    else if (combined contains "concurrent" or combined contains "session limit")
        "CONCURRENT_SESSION_LIMIT"
    else if (combined contains "revoked" or combined contains "disabled")
        "TOKEN_REVOKED"
    else if (combined contains "expired" or combined contains "invalid")
        "TOKEN_EXPIRED"
    else
        "TOKEN_EXPIRED"  // Default assumption

var isAutoRecoverable = rootCause match {
    case "TOKEN_EXPIRED"             -> true
    case "CONCURRENT_SESSION_LIMIT"  -> true
    case "SANDBOX_REFRESH"           -> false
    case "IP_RESTRICTION"            -> false
    case "TOKEN_REVOKED"             -> false
    else                             -> false
}
---
{
    rootCause: rootCause,
    isAutoRecoverable: isAutoRecoverable,
    errorMessage: errorMsg,
    attemptNumber: vars.attemptCount,
    diagnosis: rootCause match {
        case "TOKEN_EXPIRED" ->
            "OAuth access token expired. Will attempt re-authentication."
        case "CONCURRENT_SESSION_LIMIT" ->
            "Too many concurrent sessions. Will wait and retry."
        case "SANDBOX_REFRESH" ->
            "Sandbox was refreshed, invalidating all tokens and Connected App config. Manual intervention required."
        case "IP_RESTRICTION" ->
            "MuleSoft worker IP is not in the Salesforce trusted IP range. Manual intervention required."
        case "TOKEN_REVOKED" ->
            "OAuth token was manually revoked or Connected App was disabled. Manual intervention required."
        else ->
            "Unknown session error. Manual investigation required."
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <set-variable variableName="diagnosis" value="#[payload]"/>
        <logger level="WARN"
                message='Session diagnosis: #[payload.rootCause] - #[payload.diagnosis] (attempt #[payload.attemptNumber])'/>

        <!-- Step 2: Apply recovery action based on root cause -->
        <choice doc:name="Recovery Router">
            <!-- Auto-recoverable: Token Expired -->
            <when expression="#[payload.rootCause == 'TOKEN_EXPIRED']">
                <!-- Calculate exponential backoff delay -->
                <ee:transform doc:name="Calculate Backoff">
                    <ee:message>
                        <ee:set-payload><![CDATA[
%dw 2.0
output application/json
var attempt = vars.attemptCount as Number
var initialBackoff = Mule::p('sf.recovery.initialBackoffMs') as Number
var maxBackoff = Mule::p('sf.recovery.maxBackoffMs') as Number
// Exponential backoff with jitter
var backoff = min([initialBackoff * (2 pow (attempt - 1)), maxBackoff])
var jitter = randomInt(backoff / 4)
---
{
    backoffMs: backoff + jitter,
    attempt: attempt
}
                        ]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <logger level="INFO"
                        message='Waiting #[payload.backoffMs]ms before re-authentication attempt #[payload.attempt]'/>

                <!-- Force token refresh by invalidating the cached connection -->
                <salesforce:invalidate-connection config-ref="Salesforce_Config"/>

                <logger level="INFO" message="Connection invalidated. Next operation will re-authenticate."/>
            </when>

            <!-- Auto-recoverable: Concurrent Session Limit -->
            <when expression="#[payload.rootCause == 'CONCURRENT_SESSION_LIMIT']">
                <logger level="WARN"
                        message='Concurrent session limit hit. Waiting 30 seconds for sessions to clear.'/>
                <!-- Invalidate and let connector re-auth on next call -->
                <salesforce:invalidate-connection config-ref="Salesforce_Config"/>
            </when>

            <!-- Not auto-recoverable: alert and fail -->
            <otherwise>
                <logger level="ERROR"
                        message='Non-recoverable session error: #[vars.diagnosis.rootCause]. Alerting operations.'/>
                <flow-ref name="alert-operations-team"/>
                <raise-error type="APP:SESSION_NOT_RECOVERABLE"
                             description="#[vars.diagnosis.diagnosis]"/>
            </otherwise>
        </choice>
    </sub-flow>

    <!-- Operations alert sub-flow -->
    <sub-flow name="alert-operations-team">
        <ee:transform doc:name="Build Alert Payload">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    alert: "SALESFORCE_SESSION_ERROR",
    severity: if (vars.diagnosis.isAutoRecoverable) "WARNING" else "CRITICAL",
    rootCause: vars.diagnosis.rootCause,
    diagnosis: vars.diagnosis.diagnosis,
    recoveryAttempts: vars.attemptCount,
    application: app.name,
    environment: Mule::p('mule.env') default "unknown",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    runbook: vars.diagnosis.rootCause match {
        case "SANDBOX_REFRESH" ->
            "1. Get new sandbox credentials\n2. Update Connected App in sandbox\n3. Update Mule properties\n4. Restart application"
        case "IP_RESTRICTION" ->
            "1. Check Salesforce Setup > Network Access\n2. Add MuleSoft worker IP range\n3. Or add to Connected App IP relaxation"
        case "TOKEN_REVOKED" ->
            "1. Check Connected App status in Salesforce\n2. Re-enable if disabled\n3. Generate new client credentials if needed"
        else ->
            "1. Check Salesforce session settings\n2. Review connector configuration\n3. Verify OAuth scopes"
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <http:request method="POST"
                      config-ref="Alerts_HTTP_Config"
                      path="/api/alerts/salesforce-session">
            <http:body>#[payload]</http:body>
        </http:request>
    </sub-flow>
</mule>
```

**Root Cause Decision Tree**

```
INVALID_SESSION_ID received
├── Error contains "IP restrict" → IP_RESTRICTION (not auto-recoverable)
│   └── Action: Alert ops to add MuleSoft IPs to trusted range
├── Error contains "sandbox refresh" → SANDBOX_REFRESH (not auto-recoverable)
│   └── Action: Alert ops to update credentials post-refresh
├── Error contains "concurrent" / "session limit" → CONCURRENT_SESSION_LIMIT
│   └── Action: Wait 30s, invalidate connection, retry
├── Error contains "revoked" / "disabled" → TOKEN_REVOKED (not auto-recoverable)
│   └── Action: Alert ops to re-enable Connected App
└── Default → TOKEN_EXPIRED
    └── Action: Invalidate connection, exponential backoff, retry
```

## How It Works

1. **Error interception**: The `try` scope catches `SALESFORCE:INVALID_SESSION`, `SALESFORCE:CONNECTIVITY`, and `HTTP:UNAUTHORIZED` errors that all manifest as session failures.
2. **Root cause classification**: DataWeave inspects the error message text to classify the failure into one of five categories, each with different recovery semantics.
3. **Recovery routing**: Auto-recoverable causes (token expired, concurrent session limit) trigger connection invalidation and retry with exponential backoff. Non-recoverable causes (IP restriction, sandbox refresh, revoked token) alert the operations team with a specific runbook.
4. **Circuit breaker**: A counter tracks recovery attempts. After 5 failed attempts, the circuit breaker opens and stops retrying, preventing infinite loops that waste API calls and flood logs.
5. **Backoff with jitter**: Each retry waits progressively longer (2s, 4s, 8s, 16s, 32s) with random jitter to prevent thundering herd effects when multiple flows hit the same session issue.

## Key Takeaways

- Never blindly retry `INVALID_SESSION_ID`. Classify the root cause first. Retrying an IP restriction error will never succeed and wastes API calls.
- Use `salesforce:invalidate-connection` to force the connector to re-authenticate on the next operation. Simply retrying without invalidating reuses the same expired token.
- Set a maximum retry count (5 is reasonable) to prevent infinite retry loops. After exhaustion, alert operations and fail fast.
- Include specific runbooks in alerts so operations teams know exactly what to do for each root cause.
- After a sandbox refresh, all OAuth tokens, Connected App configurations, and security tokens are reset. The only fix is manual credential update.

## Related Recipes

- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
- [SF Sandbox Refresh Reconnect](../sf-sandbox-refresh-reconnect/)
- [SF Sync Loop Prevention](../sf-sync-loop-prevention/)
