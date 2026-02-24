## Decompose Monolith into API-Led Layers
> Break monolithic Mule applications into API-led connectivity architecture (Experience, Process, System)

### When to Use
- Single large Mule application handling all integration logic
- Need independent scaling, deployment, and team ownership
- Implementing MuleSoft's API-led connectivity pattern
- Application has become too complex to maintain

### Configuration / Code

#### 1. API-Led Architecture

```
Client Apps
    |
[Experience Layer]  - Channel-specific APIs (mobile, web, partner)
    |
[Process Layer]     - Business logic, orchestration, transformation
    |
[System Layer]      - System-specific connectors (Salesforce, DB, SAP)
```

#### 2. Experience API Example

```xml
<!-- experience-api/src/main/mule/customer-experience-api.xml -->
<flow name="get-customer-mobile">
    <http:listener config-ref="HTTP_Mobile" path="/v1/customers/{id}" method="GET" />

    <!-- Call Process API -->
    <http:request config-ref="Process_API"
        method="GET" path="/customers/{id}">
        <http:uri-params>#[{ 'id': attributes.uriParams.id }]</http:uri-params>
    </http:request>

    <!-- Transform for mobile -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.customerId,
    displayName: payload.firstName ++ " " ++ payload.lastName,
    avatar: payload.profileImageUrl default ""
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### 3. Process API Example

```xml
<!-- process-api/src/main/mule/customer-process-api.xml -->
<flow name="get-customer-composite">
    <http:listener config-ref="HTTP_Process" path="/customers/{id}" method="GET" />

    <!-- Orchestrate System APIs -->
    <scatter-gather>
        <route>
            <http:request config-ref="CRM_System_API"
                method="GET" path="/crm/customers/{id}" />
        </route>
        <route>
            <http:request config-ref="Billing_System_API"
                method="GET" path="/billing/accounts/{id}" />
        </route>
    </scatter-gather>

    <!-- Merge results -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var crm = payload[0].payload
var billing = payload[1].payload
---
{
    customerId: crm.id,
    firstName: crm.firstName,
    lastName: crm.lastName,
    email: crm.email,
    billingStatus: billing.status,
    balance: billing.currentBalance
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### 4. System API Example

```xml
<!-- system-api/src/main/mule/salesforce-system-api.xml -->
<flow name="get-crm-customer">
    <http:listener config-ref="HTTP_System" path="/crm/customers/{id}" method="GET" />

    <salesforce:query config-ref="Salesforce_Config">
        <salesforce:salesforce-query>
            SELECT Id, FirstName, LastName, Email
            FROM Contact WHERE Id = ':id'
        </salesforce:salesforce-query>
        <salesforce:parameters>#[{ 'id': attributes.uriParams.id }]</salesforce:parameters>
    </salesforce:query>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload[0]]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. **System Layer**: Thin wrappers around backend systems, exposing clean REST APIs
2. **Process Layer**: Business logic, data composition, orchestration across system APIs
3. **Experience Layer**: Channel-specific formatting (mobile, web, partner portals)
4. Each layer is a separate Mule application with independent lifecycle

### Migration Checklist
- [ ] Map current monolith flows to the three API layers
- [ ] Identify system boundaries (one System API per backend)
- [ ] Design canonical data models for Process layer
- [ ] Create System APIs first (bottom-up)
- [ ] Build Process APIs that orchestrate System APIs
- [ ] Build Experience APIs for each channel
- [ ] Set up API contracts (RAML/OAS) for each layer
- [ ] Register APIs in API Manager
- [ ] Implement rate limiting and security per layer
- [ ] Load test the distributed architecture

### Gotchas
- Network latency increases with each layer hop
- Over-decomposition creates unnecessary complexity
- System APIs should be reusable, not one-to-one with process needs
- Error handling must propagate correctly across layers
- Avoid the "distributed monolith" anti-pattern

### Related
- [esb-to-api-led](../esb-to-api-led/) - ESB migration
- [sync-to-event-driven](../sync-to-event-driven/) - Async patterns
