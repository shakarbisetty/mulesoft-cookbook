## Async Flow Testing
> Test async scopes, scatter-gather, and completion callbacks with deterministic assertions.

### When to Use
- You have flows using `<async>` scope for fire-and-forget processing
- You use `<scatter-gather>` to call multiple services in parallel
- You need to verify that all parallel branches complete and aggregate correctly
- You need to test callback or completion notification logic after async processing

### Configuration / Code

**MUnit test — async scope with spy processor:**

```xml
<munit:test name="async-notification-test"
            description="Verify async scope sends notification after order save"
            timeout="30000">

    <munit:behavior>
        <!-- Mock the database insert in the main flow -->
        <munit-tools:mock-when processor="db:insert">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Save Order"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value="#[1]"/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Spy on the HTTP request inside the async scope -->
        <munit-tools:spy processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Send Notification"/>
            </munit-tools:with-attributes>
            <munit-tools:before-call>
                <munit-tools:store key="notification-sent">
                    <munit-tools:value>#[true]</munit-tools:value>
                </munit-tools:store>
            </munit-tools:before-call>
        </munit-tools:spy>

        <!-- Mock the notification call itself -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Send Notification"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- {"sent": true}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="process-order-flow"/>
        <!-- Wait for async scope to complete -->
        <munit-tools:sleep time="2000"/>
    </munit:execution>

    <munit:validation>
        <!-- Verify the main flow returned success -->
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('accepted')]"/>

        <!-- Verify the async notification was triggered -->
        <munit-tools:retrieve key="notification-sent">
            <munit-tools:assert-that
                expression="#[payload]"
                is="#[MunitTools::equalTo(true)]"/>
        </munit-tools:retrieve>
    </munit:validation>
</munit:test>
```

**MUnit test — scatter-gather with error aggregation:**

```xml
<munit:test name="scatter-gather-enrichment-test"
            description="Verify scatter-gather collects data from multiple services">

    <munit:behavior>
        <!-- Mock CRM service -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get CRM Data"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value='#[output application/json --- {"name": "Acme Corp", "tier": "Gold"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Mock Billing service -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get Billing Data"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value='#[output application/json --- {"balance": 5000.00, "currency": "USD"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Mock Inventory service -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get Inventory Data"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value='#[output application/json --- {"items": 142, "warehouse": "US-EAST"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="customer-enrichment-scatter-gather-flow"/>
    </munit:execution>

    <munit:validation>
        <!-- Scatter-gather returns a map of route results -->
        <munit-tools:assert-that
            expression="#[payload.crm.name]"
            is="#[MunitTools::equalTo('Acme Corp')]"/>
        <munit-tools:assert-that
            expression="#[payload.billing.balance]"
            is="#[MunitTools::equalTo(5000.00)]"/>
        <munit-tools:assert-that
            expression="#[payload.inventory.items]"
            is="#[MunitTools::equalTo(142)]"/>
    </munit:validation>
</munit:test>
```

**MUnit test — scatter-gather partial failure:**

```xml
<munit:test name="scatter-gather-partial-failure-test"
            description="Verify scatter-gather handles one branch failing"
            expectedError="MULE:COMPOSITE_ROUTING">

    <munit:behavior>
        <!-- CRM returns successfully -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get CRM Data"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value='#[output application/json --- {"name": "Acme Corp"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Billing service throws a timeout error -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get Billing Data"/>
            </munit-tools:with-attributes>
            <munit-tools:then-throw exception="#[java!org::mule::runtime::api::exception::MuleException::new('Billing timeout')]"
                                    error="HTTP:TIMEOUT"/>
        </munit-tools:mock-when>

        <!-- Inventory returns successfully -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get Inventory Data"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value='#[output application/json --- {"items": 142}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="customer-enrichment-scatter-gather-flow"/>
    </munit:execution>
</munit:test>
```

**Flow under test — async with scatter-gather:**

```xml
<flow name="process-order-flow">
    <http:listener config-ref="HTTP_Listener" path="/orders" method="POST"/>

    <db:insert config-ref="Database_Config" doc:name="Save Order">
        <db:sql>INSERT INTO orders (id, data) VALUES (:id, :data)</db:sql>
        <db:input-parameters>#[{id: payload.orderId, data: write(payload, 'application/json')}]</db:input-parameters>
    </db:insert>

    <!-- Fire-and-forget notification -->
    <async doc:name="Async Notification">
        <http:request config-ref="Notification_Config" method="POST"
                      path="/notify" doc:name="Send Notification">
            <http:body>#[output application/json --- {orderId: payload.orderId, event: "ORDER_CREATED"}]</http:body>
        </http:request>
    </async>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{status: "accepted", orderId: payload.orderId}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. **Async scope testing**: The spy processor records that the async HTTP call was invoked, storing a flag in MUnit's object store. A sleep ensures the async thread completes before assertions run.
2. **Scatter-gather testing**: Each parallel route's external call is mocked independently. The test verifies the aggregated result contains data from all branches.
3. **Partial failure testing**: When one scatter-gather branch throws an error, a `MULE:COMPOSITE_ROUTING` error is raised. Use `expectedError` to assert this behavior.
4. **The spy + mock pattern**: Spy captures invocation metadata (before-call), while mock-when controls the return value. Both can coexist on the same processor.

### Gotchas
- **MUnit test timeout for async**: Default MUnit timeout is 10 seconds. Async processing may need 30+ seconds. Always set `timeout` on the test element
- **Scatter-gather error aggregation**: If any route fails, scatter-gather throws `MULE:COMPOSITE_ROUTING` containing all errors. You cannot assert on individual route errors directly in validation — use `expectedError` or catch the composite error
- **Sleep is fragile**: `munit-tools:sleep` is a workaround for async timing. Prefer shorter async operations in tests and use generous but bounded timeouts
- **Spy ordering with mock-when**: If you spy and mock the same processor, the spy's `before-call` fires before the mock replaces the response. The spy's `after-call` sees the mocked response
- **Variable isolation in async**: Variables set inside an `<async>` scope are copies. Changes do not propagate back to the main flow. Test assertions must account for this

### Related
- [Error Scenario Testing](../error-scenario-testing/)
- [Batch Job Testing](../batch-job-testing/)
- [Coverage Enforcement in CI/CD](../coverage-enforcement-cicd/)
