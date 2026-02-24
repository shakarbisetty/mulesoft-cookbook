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
            <munit:payload value="#[output application/json --- {message: I
