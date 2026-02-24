## Vibes MUnit Generation
> Using MuleSoft Vibes to generate MUnit tests, with a review checklist for fixing common AI mistakes.

### When to Use
- You want to bootstrap MUnit tests quickly for existing flows
- You are adopting test-driven development and want a starting point from Vibes
- You need to generate tests for legacy flows that have zero coverage
- You want to compare Vibes-generated tests against hand-written tests for quality

### Configuration / Code

**Effective prompt patterns for Vibes MUnit generation:**

```
Prompt (Good):
"Generate MUnit tests for my order-processing-flow that:
1. Mocks the Database SELECT that fetches orders (doc:name = 'Fetch Orders')
2. Mocks the HTTP POST to the fulfillment API (doc:name = 'Call Fulfillment')
3. Tests the happy path: 200 response with processed order
4. Tests error path: database CONNECTIVITY error returns 503
5. Tests error path: fulfillment API TIMEOUT returns 504
6. Uses test data from src/test/resources/test-data/orders.json"

Prompt (Bad):
"Write tests for my Mule app"
```

**Vibes output — before manual fixes:**

```xml
<!-- VIBES GENERATED — needs review -->
<munit:test name="test-order-processing-flow"
            description="Test order processing flow">

    <munit:behavior>
        <!-- ISSUE 1: Vibes mocks by processor type, not doc:name -->
        <munit-tools:mock-when processor="db:select">
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- [{"id": 1, "name": "test"}]]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- ISSUE 2: Vibes hardcodes connection config inline -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- {"status": "ok"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <!-- ISSUE 3: No input payload set -->
        <flow-ref name="order-processing-flow"/>
    </munit:execution>

    <munit:validation>
        <!-- ISSUE 4: Assertion too vague -->
        <munit-tools:assert-that
            expression="#[payload]"
            is="#[MunitTools::notNullValue()]"/>
    </munit:validation>
</munit:test>
```

**After manual fixes — production-ready:**

```xml
<munit:test name="order-processing-happy-path"
            description="Verify order processing returns fulfilled status for valid order">

    <munit:behavior>
        <!-- FIX 1: Mock by doc:name for precision -->
        <munit-tools:mock-when processor="db:select">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Fetch Orders"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value="#[output application/java --- readUrl('classpath://test-data/orders.json', 'application/json')]"/>
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- FIX 2: Mock by doc:name, realistic response shape -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Call Fulfillment"/>
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload
                    value='#[output application/json --- {"fulfillmentId": "F-12345", "status": "SHIPPED", "trackingNumber": "1Z999AA10123456784"}]'/>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <!-- FIX 3: Set realistic input payload -->
        <set-payload value="#[output application/json --- readUrl('classpath://test-data/input-order.json', 'application/json')]"/>
        <flow-ref name="order-processing-flow"/>
    </munit:execution>

    <munit:validation>
        <!-- FIX 4: Specific, meaningful assertions -->
        <munit-tools:assert-that
            expression="#[payload.status]"
            is="#[MunitTools::equalTo('FULFILLED')]"/>
        <munit-tools:assert-that
            expression="#[payload.fulfillmentId]"
            is="#[MunitTools::not(MunitTools::isEmptyOrNullString())]"/>
        <munit-tools:assert-that
            expression="#[payload.trackingNumber]"
            is="#[MunitTools::startsWith('1Z')]"/>
    </munit:validation>
</munit:test>

<!-- FIX 5: Vibes didn't generate error tests — add manually -->
<munit:test name="order-processing-db-connectivity-error"
            description="Verify 503 when database is unreachable">

    <munit:behavior>
        <munit-tools:mock-when processor="db:select">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="doc:name"
                                           whereValue="Fetch Orders"/>
            </munit-tools:with-attributes>
            <munit-tools:then-throw
                exception="#[java!org::mule::runtime::api::exception::MuleException::new('Connection refused')]"
                error="DB:CONNECTIVITY"/>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- {"orderId": "ORD-001"}]'/>
        <flow-ref name="order-processing-flow"/>
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[attributes.statusCode]"
            is="#[MunitTools::equalTo(503)]"/>
    </munit:validation>
</munit:test>
```

**Review checklist for Vibes-generated MUnit tests:**

| Check | What to Look For | Common Vibes Mistake |
|-------|-----------------|---------------------|
| Mock precision | `with-attributes` + `doc:name` present | Mocks all instances of a processor type |
| Input payload | `set-payload` before `flow-ref` | Missing input; uses whatever default payload exists |
| Assertion specificity | Asserts on specific fields and values | `notNullValue()` on entire payload |
| Error paths | Separate test per error type | No error tests generated |
| Test naming | Descriptive: `scenario-expected-result` | Generic: `test-flow-name` |
| External test data | Loads from `classpath://` resources | Hardcoded inline payloads |
| Connection configs | All external calls mocked | Some connectors not mocked (test hits real service) |
| Secure properties | No secrets in test code | Hardcoded passwords or tokens |
| Response shape | Matches actual connector response | Simplified `{"status": "ok"}` shape |
| Timeout | Set for async/batch flows | Default 10s timeout for long operations |

### How It Works
1. Write a detailed prompt describing your flow's processors (by `doc:name`), expected inputs/outputs, and error scenarios
2. Vibes generates a test XML file with mock-when blocks, flow-ref execution, and basic assertions
3. Review the output against the checklist above — fix mock precision, add missing error tests, strengthen assertions
4. Add test data files to `src/test/resources/test-data/` instead of inline hardcoded values
5. Run the fixed tests with coverage reporting to verify they actually exercise the intended code paths
6. Iterate: use Vibes for the skeleton, then manually add edge cases and error scenarios

### Gotchas
- **Vibes does not mock external connectors well**: Vibes often generates mocks without `with-attributes`, which means the mock catches ALL instances of that processor type. If your flow has two HTTP requests, both get the same mock response
- **Test names too generic**: Vibes generates names like `test-my-flow` or `test1`. Rename to pattern: `{flow}-{scenario}-{expected-result}` (e.g., `order-processing-timeout-returns-504`)
- **No error test generation**: Vibes almost never generates `then-throw` error tests. You must manually add these. Plan for at least one error test per `on-error-*` block in your flow
- **Vibes uses default configs**: Generated tests may reference config elements that do not exist in the test Mule config. Ensure your `src/test/munit/` tests import the correct config files
- **Missing secure properties**: Vibes sometimes hardcodes URLs or credentials that should come from `secure::` properties. Always verify no secrets leaked into test code
- **Context window limits**: For large flows (50+ processors), Vibes may truncate or miss processors. Split large flows into sub-flows and generate tests per sub-flow

### Related
- [Coverage Enforcement in CI/CD](../coverage-enforcement-cicd/)
- [Error Scenario Testing](../error-scenario-testing/)
- [Mock Data Generation](../mock-data-generation/)
- [Vibes Prompt Engineering](../../../ai-agents/vibes-prompt-engineering/)
- [Vibes Code Review Patterns](../../../ai-agents/vibes-code-review-patterns/)
