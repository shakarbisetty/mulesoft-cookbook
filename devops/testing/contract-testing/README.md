## Contract Testing
> Validate Mule API implementation against its RAML/OAS spec automatically

### When to Use
- You practice API-first design with RAML or OpenAPI specifications
- You need to catch spec-implementation drift before it reaches production
- You want automated validation that the API returns correct status codes, headers, and schemas

### Configuration

**Contract test using API Console validation (MUnit)**
```xml
<munit:test name="contract-test-get-orders"
    description="GET /orders matches RAML contract">
    <munit:execution>
        <http:request method="GET"
            config-ref="HTTP_Test_Config"
            path="/api/v1/orders">
            <http:query-params>
                #[{ "status": "PENDING" }]
            </http:query-params>
            <http:headers>
                #[{
                    "Accept": "application/json",
                    "x-correlation-id": "test-contract-001"
                }]
            </http:headers>
        </http:request>
    </munit:execution>
    <munit:validation>
        <!-- Status code -->
        <munit-tools:assert-that
            expression="#[attributes.statusCode]"
            is="#[MunitTools::equalTo(200)]" />

        <!-- Content-Type header -->
        <munit-tools:assert-that
            expression="#[attributes.headers.'content-type']"
            is="#[MunitTools::containsString('application/json')]" />

        <!-- Response body schema validation -->
        <munit-tools:assert-that
            expression="#[sizeOf(payload)]"
            is="#[MunitTools::greaterThan(0)]" />

        <!-- Required fields present -->
        <munit-tools:assert-that
            expression="#[payload[0].id]"
            is="#[MunitTools::notNullValue()]" />
        <munit-tools:assert-that
            expression="#[payload[0].orderNumber]"
            is="#[MunitTools::notNullValue()]" />
        <munit-tools:assert-that
            expression="#[payload[0].status]"
            is="#[MunitTools::equalTo('PENDING')]" />
    </munit:validation>
</munit:test>
```

**Prism-based contract testing (CI script)**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Start Prism as a validation proxy
npx @stoplight/prism-cli proxy \
    --errors \
    --validate-request true \
    api/order-api.oas3.yaml \
    http://localhost:8081 &
PRISM_PID=$!

sleep 3

# Run requests through Prism (validates against spec)
FAILED=0

echo "Testing GET /orders..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    http://localhost:4010/api/v1/orders)
if [ "$RESPONSE" != "200" ]; then
    echo "FAIL: GET /orders returned $RESPONSE"
    FAILED=1
fi

echo "Testing POST /orders with valid body..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://localhost:4010/api/v1/orders \
    -H "Content-Type: application/json" \
    -d '{"customerId": 1001, "items": [{"productId": "SKU-001", "quantity": 2}]}')
if [ "$RESPONSE" != "201" ]; then
    echo "FAIL: POST /orders returned $RESPONSE"
    FAILED=1
fi

echo "Testing POST /orders with invalid body (should fail)..."
RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST http://localhost:4010/api/v1/orders \
    -H "Content-Type: application/json" \
    -d '{"invalid": true}')
if [ "$RESPONSE" == "201" ]; then
    echo "FAIL: POST /orders accepted invalid body"
    FAILED=1
fi

kill $PRISM_PID 2>/dev/null

exit $FAILED
```

**Spectral linting in CI**
```yaml
# .spectral.yaml
extends: spectral:oas
rules:
  operation-operationId: error
  operation-description: warn
  oas3-api-servers: error
  no-eval-in-markdown: error
  info-contact: warn
  oas3-valid-media-example: error
```

```bash
# Run Spectral lint
npx @stoplight/spectral-cli lint api/order-api.oas3.yaml --ruleset .spectral.yaml
```

### How It Works
1. **MUnit contract tests** validate that the running app returns correct status codes, headers, and body shapes
2. **Prism proxy** sits between test client and Mule app, validating both requests and responses against the OAS spec
3. **Spectral linting** catches spec quality issues (missing descriptions, invalid examples) before implementation
4. Contract tests run in CI alongside unit tests to catch drift early
5. Both RAML and OpenAPI 3.x specs are supported; Prism works with OAS, Spectral works with both

### Gotchas
- RAML contract testing requires converting to OAS or using MuleSoft's API Console validation
- Contract tests are not a replacement for unit tests — they validate shape, not business logic
- Mock responses in Prism differ from actual app responses; test against the real app when possible
- Large APIs need prioritized contract tests — start with the most critical endpoints
- Spec-first changes must be synchronized with implementation changes in the same PR

### Related
- [newman-e2e](../newman-e2e/) — End-to-end testing
- [docker-integration](../docker-integration/) — Integration test dependencies
- [gatling-performance](../gatling-performance/) — Performance testing
