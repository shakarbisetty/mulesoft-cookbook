## Gatling Performance Testing
> Gatling load tests with regression thresholds for MuleSoft APIs

### When to Use
- You need to validate API performance under expected and peak load
- You want automated regression detection in CI (fail if p95 latency increases)
- You need detailed HTML reports showing response time distributions and throughput

### Configuration

**pom.xml — Gatling Maven plugin**
```xml
<plugin>
    <groupId>io.gatling</groupId>
    <artifactId>gatling-maven-plugin</artifactId>
    <version>4.8.0</version>
    <configuration>
        <simulationsFolder>src/test/gatling/simulations</simulationsFolder>
        <resultsFolder>target/gatling</resultsFolder>
    </configuration>
</plugin>

<dependency>
    <groupId>io.gatling.highcharts</groupId>
    <artifactId>gatling-charts-highcharts</artifactId>
    <version>3.10.3</version>
    <scope>test</scope>
</dependency>
```

**src/test/gatling/simulations/OrderApiSimulation.java**
```java
package simulations;

import io.gatling.javaapi.core.*;
import io.gatling.javaapi.http.*;
import java.time.Duration;

import static io.gatling.javaapi.core.CoreDsl.*;
import static io.gatling.javaapi.http.HttpDsl.*;

public class OrderApiSimulation extends Simulation {

    // Configuration
    String baseUrl = System.getProperty("BASE_URL", "http://localhost:8081");
    int targetUsers = Integer.parseInt(System.getProperty("TARGET_USERS", "100"));
    int rampUpSeconds = Integer.parseInt(System.getProperty("RAMP_UP_SECONDS", "60"));
    int steadySeconds = Integer.parseInt(System.getProperty("STEADY_SECONDS", "120"));

    HttpProtocolBuilder httpProtocol = http
        .baseUrl(baseUrl + "/api/v1")
        .acceptHeader("application/json")
        .contentTypeHeader("application/json")
        .header("x-correlation-id", "perf-#{randomUuid}")
        .shareConnections();

    // Scenarios
    ScenarioBuilder getOrders = scenario("Get Orders")
        .exec(
            http("GET /orders")
                .get("/orders")
                .queryParam("status", "PENDING")
                .check(status().is(200))
                .check(jsonPath("$[*]").count().gte(0))
        );

    ScenarioBuilder createOrder = scenario("Create Order")
        .exec(
            http("POST /orders")
                .post("/orders")
                .body(StringBody("""
                    {
                        "customerId": #{randomInt(1000, 9999)},
                        "items": [
                            {"productId": "SKU-001", "quantity": #{randomInt(1, 5)}},
                            {"productId": "SKU-002", "quantity": #{randomInt(1, 3)}}
                        ]
                    }
                    """))
                .check(status().is(201))
                .check(jsonPath("$.id").exists())
        );

    ScenarioBuilder mixedWorkload = scenario("Mixed Workload")
        .randomSwitch().on(
            Choice.withWeight(70, exec(getOrders)),
            Choice.withWeight(30, exec(createOrder))
        );

    // Load profile
    {
        setUp(
            mixedWorkload.injectOpen(
                rampUsers(targetUsers).during(Duration.ofSeconds(rampUpSeconds)),
                constantUsersPerSec(targetUsers / 10.0).during(Duration.ofSeconds(steadySeconds))
            )
        )
        .protocols(httpProtocol)
        .assertions(
            global().responseTime().percentile3().lt(2000),    // p95 < 2s
            global().responseTime().percentile4().lt(5000),    // p99 < 5s
            global().successfulRequests().percent().gt(99.0),  // >99% success
            global().requestsPerSec().gte(50.0)                // >=50 RPS
        );
    }
}
```

**CI pipeline integration**
```yaml
# GitHub Actions
performance-test:
  runs-on: ubuntu-latest
  needs: deploy-qa
  steps:
    - uses: actions/checkout@v4

    - name: Run Gatling performance tests
      run: |
        mvn gatling:test -B \
            -DBASE_URL=https://order-api-qa.example.com \
            -DTARGET_USERS=50 \
            -DRAMP_UP_SECONDS=30 \
            -DSTEADY_SECONDS=60

    - name: Upload Gatling report
      if: always()
      uses: actions/upload-artifact@v4
      with:
        name: gatling-report
        path: target/gatling/**/index.html
```

**run-performance-test.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-http://localhost:8081}"
USERS="${2:-100}"

echo "Running performance test against $BASE_URL with $USERS users..."

mvn gatling:test -B \
    -DBASE_URL="$BASE_URL" \
    -DTARGET_USERS="$USERS" \
    -DRAMP_UP_SECONDS=60 \
    -DSTEADY_SECONDS=120

# Check assertions
if [ $? -eq 0 ]; then
    echo "Performance test PASSED — all assertions met."
else
    echo "Performance test FAILED — check target/gatling/ for report."
    exit 1
fi
```

### How It Works
1. Gatling simulates realistic user load patterns: ramp-up followed by steady state
2. Mixed workload scenarios reflect production traffic ratios (70% reads, 30% writes)
3. Built-in assertions fail the build if p95 latency, error rate, or throughput regress
4. HTML reports show response time distributions, percentiles, and throughput over time
5. System properties make the simulation configurable without code changes

### Gotchas
- Never run performance tests against production without coordination
- QA environment must be sized similarly to production for meaningful results
- Network latency between CI runner and the API affects results; run from the same region
- Connection pooling in Gatling (`shareConnections`) behaves differently from real clients
- Start with conservative thresholds and tighten them as you establish baselines

### Related
- [newman-e2e](../newman-e2e/) — Functional end-to-end tests
- [contract-testing](../contract-testing/) — API spec validation
- [slo-sli-alerting](../../observability/slo-sli-alerting/) — Define SLOs from perf baselines
