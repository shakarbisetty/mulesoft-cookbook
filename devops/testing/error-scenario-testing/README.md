## Error Scenario Testing
> Mock connector errors, validate error handlers fire correctly, and assert on every error type.

### When to Use
- You need to verify that error handlers (`on-error-continue`, `on-error-propagate`) behave correctly
- You want to test all error types your flow might encounter: CONNECTIVITY, TIMEOUT, SECURITY, custom types
- You need to ensure error responses have the correct HTTP status code and error body
- You want regression tests that prove error handling survives refactoring

### Configuration / Code

**MUnit test — mock-when with then-throw for CONNECTIVITY error:**

```xml
<munit:test name="connectivity-error-returns-503"
            description="Verify CONNECTIVITY error triggers 503 response">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Call Backend API"/>
            </munit-tools:with-attributes>
            <munit-tools:then-throw
                exception="#[java!org::mule::runtime::api::exception::MuleException::new('Connection refused')]"
                error="HTTP:CONNECTIVITY"/>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="api-proxy-flow"/>
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[attributes.statusCode]"
            is="#[MunitTools::equalTo(503)]"/>
        <munit-tools:assert-that
            expression="#[payload.error.code]"
            is="#[MunitTools::equalTo('SERVICE_UNAVAILABLE')]"/>
        <munit-tools:assert-that
            expression="#[payload.error.message]"
            is="#[MunitTools::containsString('Backend service is unavailable')]"/>
    </munit:validation>
</munit:test>
```

**MUnit test — TIMEOUT error:**

```xml
<munit:test name="timeout-error-returns-504"
            description="Verify TIMEOUT error triggers 504 response">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Call Backend API"/>
            </munit-tools:with-attributes>
            <munit-tools:then-throw
                exception="#[java!org::mule::runtime::api::exception::MuleException::new('Request timed out')]"
                error="HTTP:TIMEOUT"/>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="api-proxy-flow"/>
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[attributes.statusCode]"
            is="#[MunitTools::equalTo(504)]"/>
        <munit-tools:assert-that
            expression="#[payload.error.code]"
            is="#[MunitTools::equalTo('GATEWAY_TIMEOUT')]"/>
    </munit:validation>
</munit:test>
```

**MUnit test — SECURITY error:**

```xml
<munit:test name="security-error-returns-401"
            description="Verify SECURITY error triggers 401 response">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Call Backend API"/>
            </munit-tools:with-attributes>
            <munit-tools:then-throw
                exception="#[java!org::mule::runtime::api::exception::MuleException::new('Invalid credentials')]"
                error="HTTP:SECURITY"/>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="api-proxy-flow"/>
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[attributes.statusCode]"
            is="#[MunitTools::equalTo(401)]"/>
        <munit-tools:assert-that
            expression="#[payload.error.code]"
            is="#[MunitTools::equalTo('UNAUTHORIZED')]"/>
    </munit:validation>
</munit:test>
```

**MUnit test — custom error type with expect-exception:**

```xml
<munit:test name="custom-validation-error-test"
            description="Verify custom APP:VALIDATION error propagates"
            expectedError="APP:VALIDATION">

    <munit:execution>
        <flow-ref name="validate-order-flow"/>
        <!-- Send invalid payload to trigger custom validation -->
        <set-payload value='#[output application/json --- {"orderId": null, "amount": -5}]'/>
    </munit:execution>
</munit:test>
```

**MUnit test — on-error-continue vs on-error-propagate:**

```xml
<munit:test name="on-error-continue-returns-fallback"
            description="Verify on-error-continue returns fallback response, not error">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Get Recommendation"/>
            </munit-tools:with-attributes>
            <munit-tools:then-throw
                exception="#[java!org::mule::runtime::api::exception::MuleException::new('Service down')]"
                error="HTTP:CONNECTIVITY"/>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="product-detail-flow"/>
    </munit:execution>

    <munit:validation>
        <!-- on-error-continue swallows the error; flow completes normally -->
        <munit-tools:assert-that
            expression="#[attributes.statusCode]"
            is="#[MunitTools::equalTo(200)]"/>
        <!-- Verify fallback recommendations were returned -->
        <munit-tools:assert-that
            expression="#[payload.recommendations]"
            is="#[MunitTools::notNullValue()]"/>
        <munit-tools:assert-that
            expression="#[payload.recommendationSource]"
            is="#[MunitTools::equalTo('fallback')]"/>
    </munit:validation>
</munit:test>
```

**Flow under test — error handler structure:**

```xml
<flow name="api-proxy-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/*" method="GET"/>

    <http:request config-ref="Backend_Config" method="GET"
                  path="#[attributes.requestPath]" doc:name="Call Backend API"/>

    <error-handler>
        <on-error-continue type="HTTP:CONNECTIVITY" enableNotifications="false">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "SERVICE_UNAVAILABLE",
        message: "Backend service is unavailable. Please retry later."
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 503}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>

        <on-error-continue type="HTTP:TIMEOUT" enableNotifications="false">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "GATEWAY_TIMEOUT",
        message: "Backend service did not respond in time."
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 504}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>

        <on-error-continue type="HTTP:SECURITY" enableNotifications="false">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "UNAUTHORIZED",
        message: "Authentication with backend failed."
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 401}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-continue>

        <on-error-propagate type="ANY">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred."
    }
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{statusCode: 500}]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. `then-throw` on a `mock-when` simulates a connector raising a specific Mule error type (e.g., `HTTP:CONNECTIVITY`)
2. The error propagates into the flow's `<error-handler>`, matching the appropriate `on-error-continue` or `on-error-propagate` block
3. For `on-error-continue`: the flow completes normally with the error handler's payload — assertions check the response body and status code
4. For `on-error-propagate`: the error propagates up. Use `expectedError` on the test to assert the error type
5. Each error type gets its own test, ensuring full coverage of the error handler chain
6. Custom error types (e.g., `APP:VALIDATION`) are raised by `<raise-error>` in the flow and tested with `expectedError`

### Gotchas
- **Error handler ordering matters**: Mule evaluates `on-error-*` blocks top to bottom. A broad `type="ANY"` before specific types swallows everything. Tests will pass but miss misconfigurations — always test the most specific error types
- **on-error-continue vs propagate assertions**: With `on-error-continue`, the test's validation block runs normally. With `on-error-propagate`, you must use `expectedError` — the validation block never executes
- **Error type hierarchy**: `HTTP:CONNECTIVITY` is a subtype of `MULE:CONNECTIVITY`. If your handler catches `MULE:CONNECTIVITY`, it catches both HTTP and non-HTTP connectivity errors. Be specific in your `then-throw` error type
- **Custom error types require declaration**: If testing `APP:VALIDATION`, ensure the error type is declared in the Mule config. Undeclared types cause deployment failures, not test failures
- **Error handler in sub-flows**: Sub-flows do not have their own error handlers. Errors propagate to the calling flow. Test the calling flow, not the sub-flow, for error handling behavior

### Related
- [Async Flow Testing](../async-flow-testing/)
- [Coverage Enforcement in CI/CD](../coverage-enforcement-cicd/)
- [Batch Job Testing](../batch-job-testing/)
