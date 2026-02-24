## Composite API Patterns
> Execute multiple Salesforce operations in a single round-trip using the Composite API

### When to Use
- You need to create a parent record and related children in one API call (e.g., Account + Contacts)
- You want to reduce API call consumption by bundling multiple operations
- You need to reference the ID of a just-created record in a subsequent operation within the same request
- You want atomic operations across multiple objects (allOrNone mode)

### Configuration / Code

**Basic Composite Request via HTTP Requester**

```xml
<flow name="composite-api-flow">
    <http:listener config-ref="HTTPS_Listener"
        path="/api/create-account-with-contacts"
        allowedMethods="POST"/>

    <set-variable variableName="requestData" value="#[payload]"/>

    <!-- Build composite request body -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var account = vars.requestData.account
var contacts = vars.requestData.contacts
---
{
    allOrNone: true,
    compositeRequest: [
        // Step 1: Create the Account
        {
            method: "POST",
            url: "/services/data/v59.0/sobjects/Account",
            referenceId: "newAccount",
            body: {
                Name: account.name,
                Industry: account.industry,
                BillingStreet: account.billingStreet,
                BillingCity: account.billingCity,
                BillingState: account.billingState,
                BillingPostalCode: account.billingPostalCode
            }
        }
    ] ++ (contacts map ((contact, idx) -> {
        // Step 2+: Create Contacts referencing the new Account
        method: "POST",
        url: "/services/data/v59.0/sobjects/Contact",
        referenceId: "newContact_$(idx)",
        body: {
            FirstName: contact.firstName,
            LastName: contact.lastName,
            Email: contact.email,
            Phone: contact.phone,
            AccountId: "@{newAccount.id}"
        }
    }))
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Execute composite request -->
    <http:request method="POST"
        config-ref="Salesforce_REST_Config"
        path="/services/data/v59.0/composite">
        <http:headers>#[{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' ++ vars.sfAccessToken
        }]</http:headers>
    </http:request>

    <!-- Process response -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    success: (payload.compositeResponse filter (r) -> r.httpStatusCode >= 400) is Empty,
    accountId: (payload.compositeResponse filter (r) ->
        r.referenceId == "newAccount")[0].body.id default null,
    contacts: (payload.compositeResponse filter (r) ->
        r.referenceId startsWith "newContact_") map (r) -> {
            referenceId: r.referenceId,
            id: r.body.id default null,
            status: r.httpStatusCode,
            errors: r.body.errors default []
    }
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

**Conditional Update Pattern (Query Then Update)**

```dataweave
%dw 2.0
output application/json
---
{
    allOrNone: false,
    compositeRequest: [
        // Step 1: Query for existing record
        {
            method: "GET",
            url: "/services/data/v59.0/query?q=" ++
                "SELECT Id, Status__c FROM Order__c WHERE External_Id__c = 'ORD-001'",
            referenceId: "queryOrder"
        },
        // Step 2: Update if found (conditional via reference)
        {
            method: "PATCH",
            url: "/services/data/v59.0/sobjects/Order__c/@{queryOrder.records[0].Id}",
            referenceId: "updateOrder",
            body: {
                Status__c: "Shipped",
                Shipped_Date__c: now() as String { format: "yyyy-MM-dd" }
            }
        }
    ]
}
```

**sObject Collections (Bulk Create in Composite)**

```dataweave
%dw 2.0
output application/json

// sObject Collections allow up to 200 records per subrequest
var contactBatches = vars.contacts divideBy 200
---
{
    allOrNone: false,
    compositeRequest: contactBatches map ((batch, idx) -> {
        method: "POST",
        url: "/services/data/v59.0/composite/sobjects",
        referenceId: "contactBatch_$(idx)",
        body: {
            allOrNone: false,
            records: batch map (c) -> {
                attributes: { "type": "Contact" },
                FirstName: c.firstName,
                LastName: c.lastName,
                Email: c.email,
                AccountId: c.accountId
            }
        }
    })
}
```

**Composite Response Error Handling**

```xml
<flow name="composite-error-handling">
    <http:request method="POST"
        config-ref="Salesforce_REST_Config"
        path="/services/data/v59.0/composite">
        <http:headers>#[{
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ' ++ vars.sfAccessToken
        }]</http:headers>
    </http:request>

    <!-- Check for partial failures -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var responses = payload.compositeResponse
var failures = responses filter (r) -> r.httpStatusCode >= 400
var successes = responses filter (r) -> r.httpStatusCode < 400
---
{
    totalRequests: sizeOf(responses),
    successful: sizeOf(successes),
    failed: sizeOf(failures),
    failureDetails: failures map (f) -> {
        referenceId: f.referenceId,
        statusCode: f.httpStatusCode,
        errors: f.body flatMap (b) -> (b default []) map (e) -> {
            errorCode: e.errorCode default "UNKNOWN",
            message: e.message default "No message",
            fields: e.fields default []
        }
    }
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <choice>
        <when expression="#[payload.failed > 0 and payload.successful > 0]">
            <logger level="WARN"
                message='Composite partial failure: #[payload.failed]/#[payload.totalRequests] failed'/>
            <flow-ref name="handle-partial-composite-failure"/>
        </when>
        <when expression="#[payload.failed > 0 and payload.successful == 0]">
            <raise-error type="APP:COMPOSITE_TOTAL_FAILURE"
                description="All composite subrequests failed"/>
        </when>
    </choice>
</flow>
```

### How It Works
1. The Composite API accepts a JSON body with an array of `compositeRequest` objects, each representing a Salesforce REST API call
2. Subrequests execute in order, and each can reference the output of previous subrequests using `@{referenceId.field}` syntax
3. When `allOrNone: true`, any failed subrequest rolls back all prior operations in the same request
4. When `allOrNone: false`, each subrequest succeeds or fails independently, enabling partial success handling
5. The response contains a `compositeResponse` array with the status code and body for each subrequest
6. sObject Collections within composite subrequests allow bulk DML (up to 200 records per collection call)

### Gotchas
- **25 subrequest limit**: A single composite request cannot exceed 25 subrequests. For larger operations, split into multiple composite calls or use sObject Collections (200 records per subrequest)
- **allOrNone rollback scope**: Rollback applies to all subrequests in the composite request, not just the failed one. If subrequest 15 fails, subrequests 1-14 are rolled back
- **Reference ID constraints**: Reference IDs must be unique within a request and can only reference earlier subrequests. Forward references are not supported
- **No nested composites**: You cannot nest a composite request inside another composite request. Use sObject Collections for bulk operations within a composite call
- **GET subrequests count toward limits**: Query subrequests in composite still consume SOQL query limits. A composite with 10 SOQL queries uses 10 of your 100 per-transaction limit
- **Binary data not supported**: Composite API does not support binary payloads (e.g., file attachments). Use the standard REST API for ContentVersion inserts
- **Error messages reference internal IDs**: When `allOrNone: true` triggers a rollback, error messages may reference `referenceId` values that the calling system must map back to business entities

### Related
- [Governor Limit Safe Batch](../governor-limit-safe-batch/)
- [Bulk API 2.0 Partial Failure](../bulk-api-2-partial-failure/)
- [Agentforce Mule Action Registration](../agentforce-mule-action-registration/)
- [Data Migration Strategies](../data-migration-strategies/)
