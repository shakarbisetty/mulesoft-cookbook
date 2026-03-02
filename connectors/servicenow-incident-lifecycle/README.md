## ServiceNow Incident Lifecycle

> Automated incident create, update, resolve, and close workflows with state transitions, SLA tracking, and bidirectional sync for MuleSoft.

### When to Use

- Automating incident creation from monitoring alerts (Datadog, Splunk, PagerDuty)
- Building bidirectional sync between ServiceNow and an external ticketing system (Jira, Azure DevOps)
- Need to enforce state transition rules (New -> In Progress -> Resolved -> Closed) in the integration layer
- Auto-resolving incidents when the triggering condition clears (e.g., server comes back online)

### The Problem

ServiceNow's incident table has strict state transitions, mandatory fields per state, and SLA timers that start/stop based on state changes. A naive integration that updates the `state` field directly can violate business rules, skip required fields, and corrupt SLA calculations. The integration must understand ServiceNow's incident lifecycle and populate the right fields at each transition.

### Configuration

#### ServiceNow Connector Config

```xml
<servicenow:config name="ServiceNow_Config" doc:name="ServiceNow Config">
    <servicenow:basic-connection
        instance="${snow.instance}"
        userName="${snow.username}"
        password="${snow.password}" />
</servicenow:config>
```

#### Create Incident from Alert

```xml
<flow name="snow-incident-create-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/incidents"
        allowedMethods="POST" />

    <!-- Validate required fields -->
    <validation:is-not-blank-string
        value="#[payload.shortDescription]"
        message="shortDescription is required" />

    <ee:transform doc:name="Map to ServiceNow Fields">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

// ServiceNow incident states
var STATE_NEW = 1
var STATE_IN_PROGRESS = 2
var STATE_ON_HOLD = 3
var STATE_RESOLVED = 6
var STATE_CLOSED = 7

// Impact/Urgency to Priority matrix
fun calculatePriority(impact: Number, urgency: Number): Number =
    if (impact == 1 and urgency == 1) 1          // Critical
    else if (impact <= 2 and urgency <= 2) 2      // High
    else if (impact <= 2 or urgency <= 2) 3       // Moderate
    else 4                                         // Low
---
{
    short_description: payload.shortDescription,
    description: payload.description default "",
    caller_id: payload.callerId default "",
    category: payload.category default "software",
    subcategory: payload.subcategory default "",
    impact: payload.impact default 3,
    urgency: payload.urgency default 3,
    priority: calculatePriority(payload.impact default 3, payload.urgency default 3),
    assignment_group: payload.assignmentGroup default "",
    assigned_to: payload.assignedTo default "",
    state: STATE_NEW,
    contact_type: payload.contactType default "integration",
    cmdb_ci: payload.configurationItem default "",
    correlation_id: payload.correlationId default "",
    correlation_display: payload.sourceSystem default "MuleSoft"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <servicenow:insert config-ref="ServiceNow_Config"
        doc:name="Create Incident"
        type="incident" />

    <ee:transform doc:name="Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    incidentNumber: payload.number,
    sysId: payload.sys_id,
    state: "New",
    createdAt: payload.sys_created_on,
    url: "https://${snow.instance}.service-now.com/incident.do?sys_id=" ++ payload.sys_id
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Update Incident State with Validation

```xml
<flow name="snow-incident-update-state-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/incidents/{sysId}/transition"
        allowedMethods="PUT" />

    <set-variable variableName="sysId" value="#[attributes.uriParams.sysId]" />
    <set-variable variableName="targetState" value="#[payload.targetState]" />

    <!-- Get current incident state -->
    <servicenow:get-record config-ref="ServiceNow_Config"
        doc:name="Get Current Incident"
        type="incident">
        <servicenow:sys-id>#[vars.sysId]</servicenow:sys-id>
    </servicenow:get-record>

    <set-variable variableName="currentState"
        value="#[payload.state as Number]" />

    <!-- Validate state transition -->
    <ee:transform doc:name="Validate Transition">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
// Valid state transitions
var validTransitions = {
    "1": [2, 3, 6, 7],   // New -> InProgress, OnHold, Resolved, Closed
    "2": [1, 3, 6],       // InProgress -> New, OnHold, Resolved
    "3": [1, 2, 6],       // OnHold -> New, InProgress, Resolved
    "6": [2, 7],           // Resolved -> InProgress, Closed
    "7": []                // Closed -> nothing (immutable)
}
var currentStr = vars.currentState as String
var targetNum = vars.targetState as Number
---
{
    isValid: (validTransitions[currentStr] default []) contains targetNum,
    currentState: vars.currentState,
    targetState: targetNum
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <choice doc:name="Valid Transition?">
        <when expression="#[payload.isValid]">
            <ee:transform doc:name="Build Update Payload">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
var target = vars.targetState as Number
---
{
    state: target,
    // Resolved requires resolution code and notes
    (close_code: payload.resolutionCode default "Solved (Permanently)") if (target == 6),
    (close_notes: payload.resolutionNotes default "Resolved via integration") if (target == 6),
    // Closed requires close code and notes
    (close_code: payload.closeCode default "Solved (Permanently)") if (target == 7),
    (close_notes: payload.closeNotes default "Closed via integration") if (target == 7),
    // On Hold requires reason
    (hold_reason: payload.holdReason default "Awaiting Vendor") if (target == 3),
    work_notes: payload.workNotes default "State updated via MuleSoft integration"
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>

            <servicenow:update config-ref="ServiceNow_Config"
                doc:name="Update Incident"
                type="incident">
                <servicenow:sys-id>#[vars.sysId]</servicenow:sys-id>
            </servicenow:update>

            <ee:transform doc:name="Success Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "updated",
    incidentNumber: payload.number,
    previousState: vars.currentState,
    newState: vars.targetState
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </when>
        <otherwise>
            <set-payload value="#[output application/json --- {
                error: 'INVALID_TRANSITION',
                message: 'Cannot transition from state $(vars.currentState) to $(vars.targetState)',
                currentState: vars.currentState,
                requestedState: vars.targetState
            }]" />
            <set-variable variableName="httpStatus" value="409" />
        </otherwise>
    </choice>
</flow>
```

#### Auto-Resolve from Monitoring Clear

```xml
<flow name="snow-incident-auto-resolve-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/incidents/auto-resolve"
        allowedMethods="POST" />

    <!-- Find open incidents by correlation ID -->
    <servicenow:get-records config-ref="ServiceNow_Config"
        doc:name="Find Open Incidents"
        type="incident">
        <servicenow:query-filter><![CDATA[correlation_id=#[payload.correlationId]^stateIN1,2,3]]></servicenow:query-filter>
    </servicenow:get-records>

    <choice doc:name="Found Open Incidents?">
        <when expression="#[sizeOf(payload) > 0]">
            <foreach doc:name="Resolve Each" collection="#[payload]">
                <ee:transform doc:name="Build Resolve Payload">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    state: 6,
    close_code: "Solved (Permanently)",
    close_notes: "Auto-resolved: monitoring condition cleared at " ++
        (now() as String {format: "yyyy-MM-dd HH:mm:ss"}) ++
        ". Source: " ++ (vars.rootPayload.sourceSystem default "monitoring"),
    work_notes: "Incident auto-resolved by MuleSoft integration. Alert cleared."
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <servicenow:update config-ref="ServiceNow_Config"
                    doc:name="Resolve Incident"
                    type="incident">
                    <servicenow:sys-id>#[payload.sys_id]</servicenow:sys-id>
                </servicenow:update>
            </foreach>

            <ee:transform doc:name="Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    resolvedCount: sizeOf(payload),
    correlationId: vars.rootPayload.correlationId
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </when>
        <otherwise>
            <set-payload value="#[output application/json --- {
                message: 'No open incidents found for correlation ID',
                correlationId: payload.correlationId
            }]" />
        </otherwise>
    </choice>
</flow>
```

#### Bidirectional Sync Sub-Flow

```xml
<sub-flow name="snow-incident-bidirectional-sync-subflow">
    <ee:transform doc:name="Map External Ticket to ServiceNow">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
// Map external system states to ServiceNow states
fun mapExternalState(externalState: String): Number =
    externalState match {
        case "open" -> 1
        case "in_progress" -> 2
        case "pending" -> 3
        case "resolved" -> 6
        case "closed" -> 7
        else -> 1
    }
---
{
    state: mapExternalState(payload.status),
    short_description: payload.title,
    description: payload.body,
    priority: payload.priority default 3,
    work_notes: "Synced from $(payload.sourceSystem) ticket $(payload.externalId) at " ++
        (now() as String {format: "yyyy-MM-dd HH:mm:ss"}),
    correlation_id: payload.externalId,
    correlation_display: payload.sourceSystem
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>
```

### Gotchas

- **State transitions are enforced server-side** — Even if your integration sends a valid state change, ServiceNow business rules can block it. For example, resolving without `close_code` and `close_notes` triggers a validation error. Always populate the required fields for each target state
- **`correlation_id` is your dedup key** — Use the `correlation_id` and `correlation_display` fields to link ServiceNow incidents to external system records. This enables bidirectional sync and auto-resolution without duplicate incidents
- **SLA timers and state** — Moving an incident to On Hold (state=3) pauses SLA timers. Moving it back to In Progress resumes them. If your integration does not handle this correctly, SLA reports will be inaccurate
- **Closed incidents are immutable** — Once an incident reaches state=7 (Closed), it cannot be updated. If you need to reopen, you must create a new incident and link it to the original
- **ServiceNow API returns XML by default** — The ServiceNow connector uses the Table API which returns JSON, but if you use raw HTTP requests, set `Accept: application/json` explicitly
- **Sys_id vs Number** — Always use `sys_id` (the 32-character GUID) for API operations, not the human-readable `number` (INC0010001). The number is not unique across instances and is not the primary key

### Testing

```xml
<munit:test name="snow-invalid-transition-test"
    description="Verify invalid state transition returns 409">

    <munit:behavior>
        <munit-tools:mock-when processor="servicenow:get-record">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{state: '7', number: 'INC0010001'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="sysId" value="abc123" />
        <set-payload value="#[{targetState: 2}]" />
        <flow-ref name="snow-incident-update-state-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.error]"
            is="#[MunitTools::equalTo('INVALID_TRANSITION')]" />
    </munit:validation>
</munit:test>
```

### Related

- [ServiceNow CMDB](../servicenow-cmdb/) — CMDB integration patterns for configuration items referenced by incidents
- [Workday Parallel Pagination](../workday-parallel-pagination/) — Parallel pagination techniques applicable to ServiceNow table queries
