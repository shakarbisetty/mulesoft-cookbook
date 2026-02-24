## Newman End-to-End Testing
> Run Postman collections as automated end-to-end tests in CI

### When to Use
- Your team already maintains Postman collections for API testing
- You need end-to-end smoke tests that run after deployment
- You want non-developers (QA team) to author test cases in a visual tool

### Configuration

**postman/order-api-e2e.json (exported collection, key sections)**
```json
{
    "info": {
        "name": "Order API E2E Tests",
        "schema": "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    "item": [
        {
            "name": "Health Check",
            "request": {
                "method": "GET",
                "url": "{{baseUrl}}/api/v1/health"
            },
            "event": [{
                "listen": "test",
                "script": {
                    "exec": [
                        "pm.test('Health check returns 200', function() {",
                        "    pm.response.to.have.status(200);",
                        "});",
                        "pm.test('Status is UP', function() {",
                        "    var body = pm.response.json();",
                        "    pm.expect(body.status).to.eql('UP');",
                        "});"
                    ]
                }
            }]
        },
        {
            "name": "Create Order",
            "request": {
                "method": "POST",
                "url": "{{baseUrl}}/api/v1/orders",
                "header": [
                    {"key": "Content-Type", "value": "application/json"}
                ],
                "body": {
                    "mode": "raw",
                    "raw": "{\"customerId\": 1001, \"items\": [{\"productId\": \"SKU-001\", \"quantity\": 2}]}"
                }
            },
            "event": [{
                "listen": "test",
                "script": {
                    "exec": [
                        "pm.test('Order created successfully', function() {",
                        "    pm.response.to.have.status(201);",
                        "});",
                        "pm.test('Order ID returned', function() {",
                        "    var body = pm.response.json();",
                        "    pm.expect(body.id).to.not.be.undefined;",
                        "    pm.environment.set('orderId', body.id);",
                        "});",
                        "pm.test('Response time < 2s', function() {",
                        "    pm.expect(pm.response.responseTime).to.be.below(2000);",
                        "});"
                    ]
                }
            }]
        },
        {
            "name": "Get Created Order",
            "request": {
                "method": "GET",
                "url": "{{baseUrl}}/api/v1/orders/{{orderId}}"
            },
            "event": [{
                "listen": "test",
                "script": {
                    "exec": [
                        "pm.test('Order retrieved', function() {",
                        "    pm.response.to.have.status(200);",
                        "});",
                        "pm.test('Order data matches', function() {",
                        "    var body = pm.response.json();",
                        "    pm.expect(body.customerId).to.eql(1001);",
                        "    pm.expect(body.status).to.eql('PENDING');",
                        "});"
                    ]
                }
            }]
        }
    ]
}
```

**postman/env-dev.json**
```json
{
    "name": "DEV Environment",
    "values": [
        {"key": "baseUrl", "value": "https://order-api-dev.us-e2.cloudhub.io", "enabled": true},
        {"key": "apiKey", "value": "dev-api-key-here", "enabled": true}
    ]
}
```

**CI pipeline integration**
```yaml
# GitHub Actions
e2e-test:
  runs-on: ubuntu-latest
  needs: deploy-dev
  steps:
    - uses: actions/checkout@v4

    - name: Install Newman
      run: npm install -g newman newman-reporter-htmlextra

    - name: Run E2E tests
      run: |
        newman run postman/order-api-e2e.json \
            --environment postman/env-dev.json \
            --reporters cli,htmlextra,junit \
            --reporter-htmlextra-export target/newman/report.html \
            --reporter-junit-export target/newman/results.xml \
            --delay-request 500 \
            --iteration-count 1 \
            --bail

    - name: Publish test results
      if: always()
      uses: dorny/test-reporter@v1
      with:
        name: Newman E2E Results
        path: target/newman/results.xml
        reporter: java-junit

    - name: Upload HTML report
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: newman-report
        path: target/newman/report.html
```

**run-e2e.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-dev}"
COLLECTION="postman/order-api-e2e.json"
ENVIRONMENT="postman/env-${ENV}.json"

echo "Running E2E tests against $ENV..."

newman run "$COLLECTION" \
    --environment "$ENVIRONMENT" \
    --reporters cli,htmlextra \
    --reporter-htmlextra-export "target/newman/report-${ENV}.html" \
    --delay-request 500 \
    --bail

echo "E2E tests passed. Report: target/newman/report-${ENV}.html"
```

### How It Works
1. Postman collections define the test sequence with assertions (status codes, body validation, timing)
2. Newman runs collections headlessly in CI — no Postman GUI required
3. Environment files swap the base URL and credentials per target environment
4. Variables set in one request (e.g., `orderId`) are available in subsequent requests
5. JUnit and HTML reporters provide CI-integrated results and human-readable reports
6. `--bail` stops execution on first failure for fast feedback

### Gotchas
- Newman does not share cookies between requests by default; enable `--cookie-jar` if needed
- Collection variable order matters — `pm.environment.set()` in one request is available in the next
- `--delay-request 500` prevents rate limiting on the API under test
- Large collections can timeout in CI; split into focused collections per domain
- Postman Cloud sync is not needed — export collections to JSON and commit to Git

### Related
- [docker-integration](../docker-integration/) — Integration test dependencies
- [contract-testing](../contract-testing/) — API spec validation
- [gatling-performance](../gatling-performance/) — Load testing
