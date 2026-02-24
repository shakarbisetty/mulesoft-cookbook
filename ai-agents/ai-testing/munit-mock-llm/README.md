## MUnit Mock for LLM Responses
> Mock AI connector responses in MUnit tests for deterministic testing.

### When to Use
- Unit testing flows that call LLM APIs
- Avoiding real API calls (and costs) during CI/CD
- Testing error handling for LLM failures

### Configuration / Code

```xml
<munit:test name="test-email-classifier" description="Test email classification with mocked LLM">
    <munit:behavior>
        <munit:set-event>
            <munit:payload value='#[output application/json --- {
                message: "I need a refund for order #12345"
            }]'/>
        </munit:set-event>
        <!-- Mock the AI connector to return a fixed classification -->
        <munit-tools:mock-when processor="ai:chat-completions">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="config-ref" whereValue="AI_Config"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- {
                    choices: [{
                        message: {role: "assistant", content: "BILLING"},
                        finish_reason: "stop"
                    }],
                    usage: {prompt_tokens: 42, completion_tokens: 1, total_tokens: 43}
                }]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>
    <munit:execution>
        <flow-ref name="email-classifier"/>
    </munit:execution>
    <munit:validation>
        <munit-tools:assert-that expression="#[payload.category]" is="#[MunitTools::equalTo('BILLING')]"/>
    </munit:validation>
</munit:test>

<!-- Test LLM timeout handling -->
<munit:test name="test-llm-timeout" description="Verify graceful handling of LLM timeout">
    <munit:behavior>
        <munit:set-event>
            <munit:payload value='#[output application/json --- {message: "Hello"}]'/>
        </munit:set-event>
        <munit-tools:mock-when processor="ai:chat-completions">
            <munit-tools:then-throw exception="#[new java!org::mule::runtime::api::connection::ConnectionException('Connection timed out')]"/>
        </munit-tools:mock-when>
    </munit:behavior>
    <munit:execution>
        <flow-ref name="email-classifier"/>
    </munit:execution>
    <munit:validation>
        <munit-tools:assert-that expression="#[payload.error]" is="#[MunitTools::containsString('unavailable')]"/>
    </munit:validation>
</munit:test>
```

### How It Works
1. `munit-tools:mock-when` intercepts calls to `ai:chat-completions` processor
2. The mock returns a fixed JSON response matching the LLM API format
3. `with-attributes` ensures only the specific AI config is mocked (not all AI calls)
4. `then-return` provides the deterministic response including `choices` and `usage`
5. The test validates the flow correctly extracts the classification from the LLM response
6. The timeout test uses `then-throw` to simulate connection failures
7. Both tests run without network access, making them fast and CI-friendly

### Gotchas
- Match the exact processor name — `ai:chat-completions` for MuleSoft AI Connector, `http:request` for raw HTTP
- Include `usage` in mock responses if your flow tracks token consumption
- Mock the full response shape — partial mocks cause NullPointerExceptions downstream
- Use `then-throw` with the correct exception class for your error scenario
- Run mocked tests with `-Dmunit.test` flag to avoid accidentally hitting real APIs

### Related
- [Response Quality Metrics](../response-quality-metrics/) — evaluating LLM output quality
- [Tracing Agent Calls](../tracing-agent-calls/) — debugging AI interactions
- [Email Classifier](../../practical-recipes/email-classifier/) — the flow being tested here
