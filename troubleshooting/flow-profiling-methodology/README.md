## Flow Profiling Methodology
> Identify the slowest component in your flow without guessing — systematic profiling for Mule 4

### When to Use
- API response times are too slow but you don't know which component is the bottleneck
- Flow processes correctly but takes longer than the SLA allows
- Performance degraded after a change and you need to find which component regressed
- Need to justify optimization effort with actual numbers
- Preparing performance test results for production sign-off

### The Problem

A Mule flow might have 10-20 components. Without profiling, developers guess which one is slow (usually blaming the database) and optimize the wrong thing. Systematic profiling identifies the actual bottleneck in minutes, not days.

### Method 1: Elapsed Time Logging (Quickest)

Add timestamp variables at key points in the flow:

```xml
<flow name="orderFlow">
    <http:listener config-ref="HTTP" path="/orders"/>

    <!-- Start timer -->
    <set-variable variableName="t_start" value="#[now()]"/>

    <!-- Component 1: Database lookup -->
    <db:select config-ref="DB" doc:name="Get Order">
        <db:sql>SELECT * FROM orders WHERE id = :id</db:sql>
        <db:input-parameters>#[{id: attributes.queryParams.orderId}]</db:input-parameters>
    </db:select>
    <set-variable variableName="t_db"
        value="#[now() as Number - vars.t_start as Number]"/>

    <!-- Component 2: Transform -->
    <ee:transform doc:name="Map Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map (order) -> {
    orderId: order.id,
    total: order.amount
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <set-variable variableName="t_transform"
        value="#[now() as Number - vars.t_start as Number - vars.t_db]"/>

    <!-- Component 3: External API call -->
    <http:request config-ref="Inventory_API" method="GET"
        path="/stock/#[vars.orderId]"/>
    <set-variable variableName="t_api"
        value="#[now() as Number - vars.t_start as Number - vars.t_db - vars.t_transform]"/>

    <!-- Log timing breakdown -->
    <logger level="INFO" message="#['PERF | DB: $(vars.t_db)ms | Transform: $(vars.t_transform)ms | API: $(vars.t_api)ms | Total: $(now() as Number - vars.t_start as Number)ms']"/>
</flow>
```

**Sample output:**
```
PERF | DB: 45ms | Transform: 12ms | API: 234ms | Total: 295ms
PERF | DB: 38ms | Transform: 15ms | API: 1205ms | Total: 1262ms  <-- API is the bottleneck
PERF | DB: 520ms | Transform: 11ms | API: 189ms | Total: 724ms   <-- DB is slow this time
```

### Method 2: Notifications API (No Code Changes)

Mule's built-in notification system can log every component execution without modifying your flows:

```xml
<!-- In your global Mule config -->
<notifications>
    <notification event="MESSAGE-PROCESSOR"/>
</notifications>

<notification-listener ref="perfNotificationListener"/>

<spring:beans>
    <spring:bean id="perfNotificationListener"
        class="com.mycompany.PerfNotificationListener"/>
</spring:beans>
```

```java
// PerfNotificationListener.java
import org.mule.runtime.api.notification.MessageProcessorNotification;
import org.mule.runtime.api.notification.MessageProcessorNotificationListener;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class PerfNotificationListener
    implements MessageProcessorNotificationListener<MessageProcessorNotification> {

    private static final Logger log = LoggerFactory.getLogger("PERF");

    @Override
    public void onNotification(MessageProcessorNotification notification) {
        log.info("PERF | {} | {} | action={} | path={}",
            notification.getComponent().getIdentifier().getName(),
            notification.getComponent().getLocation().getLocation(),
            notification.getActionName(),
            notification.getComponent().getLocation().getFileName()
        );
    }
}
```

### Method 3: Anypoint Monitoring (No Code Changes, CloudHub)

If you have Anypoint Monitoring (Titanium tier), use built-in flow profiling:

1. Navigate to **Anypoint Monitoring > Built-in Dashboards > Mule App**
2. Select your application
3. Go to **Performance** tab
4. Look at **Average Response Time by Flow** and **Message Count by Processor**
5. Drill into slow flows to see per-processor timing

**Via the Anypoint Monitoring API:**
```bash
# Get flow metrics (requires Anypoint auth token)
curl -s -H "Authorization: Bearer ${ANYPOINT_TOKEN}" \
  "https://anypoint.mulesoft.com/monitoring/query/api/v1/organizations/${ORG_ID}/environments/${ENV_ID}/apps/${APP_NAME}/metrics" \
  -d '{"queries":[{"metric":"mule.app.processor.response_time","dimensions":{"flow_name":"orderFlow"},"timeRange":"LAST_1_HOUR"}]}' | jq .
```

### Method 4: Custom Micrometer Metrics (Production-Grade)

```xml
<!-- Add Micrometer dependency to your pom.xml -->
<!-- Then instrument key operations: -->

<flow name="orderFlow">
    <http:listener config-ref="HTTP" path="/orders"/>

    <!-- Custom timer around DB operation -->
    <scripting:execute engine="groovy">
        <scripting:code>
            def timer = registry.timer("order.db.query")
            def sample = io.micrometer.core.instrument.Timer.start(registry)
            // Store sample in flow variable
            vars.dbTimerSample = sample
        </scripting:code>
    </scripting:execute>

    <db:select config-ref="DB">
        <db:sql>SELECT * FROM orders WHERE id = :id</db:sql>
        <db:input-parameters>#[{id: attributes.queryParams.orderId}]</db:input-parameters>
    </db:select>

    <scripting:execute engine="groovy">
        <scripting:code>
            vars.dbTimerSample.stop(registry.timer("order.db.query"))
        </scripting:code>
    </scripting:execute>
</flow>
```

### Diagnostic Steps: Finding the Bottleneck

#### Step 1: Establish Baseline

```bash
# Send 100 requests and capture response times
for i in $(seq 1 100); do
  curl -s -o /dev/null -w "%{time_total}\n" http://localhost:8081/api/orders?orderId=$i
done | sort -n | awk '
  {a[NR]=$1; sum+=$1}
  END {
    print "Min:", a[1]*1000, "ms"
    print "P50:", a[int(NR*0.5)]*1000, "ms"
    print "P90:", a[int(NR*0.9)]*1000, "ms"
    print "P99:", a[int(NR*0.99)]*1000, "ms"
    print "Max:", a[NR]*1000, "ms"
    print "Avg:", sum/NR*1000, "ms"
  }
'
```

#### Step 2: Identify the Slow Component

Using the elapsed time logging from Method 1:
```bash
# Extract timing logs and find the worst component
grep "PERF" mule_ee.log | awk -F'|' '{
  for(i=2; i<=NF; i++) {
    split($i, parts, ":")
    gsub(/^ +| +$/, "", parts[1])
    gsub(/[^0-9.]/, "", parts[2])
    sums[parts[1]] += parts[2]
    counts[parts[1]]++
  }
}
END {
  for(k in sums) if(counts[k]>0) printf "%s: avg=%.1fms (n=%d)\n", k, sums[k]/counts[k], counts[k]
}' | sort -t= -k2 -rn
```

**Sample output:**
```
API: avg=234.5ms (n=100)       <-- BOTTLENECK
DB: avg=42.3ms (n=100)
Transform: avg=11.8ms (n=100)
```

#### Step 3: Drill Into the Bottleneck

Once identified, investigate the specific component:

**If HTTP Request is slow:**
```bash
# Test downstream directly
curl -w "\nDNS: %{time_namelookup}\nConnect: %{time_connect}\nTLS: %{time_appconnect}\nFirst byte: %{time_starttransfer}\nTotal: %{time_total}\n" \
  https://inventory-api.example.com/stock/12345
```

**If Database is slow:**
```sql
-- Check for missing indexes
EXPLAIN SELECT * FROM orders WHERE id = '12345';

-- Check active queries
SELECT * FROM information_schema.processlist WHERE time > 5;
```

**If DataWeave transform is slow:**
```bash
# Check payload size vs. transform time correlation
grep "PERF" mule_ee.log | awk '{print $NF}' | sort -n
# If large payloads = slow transforms, consider streaming
```

#### Step 4: Verify the Fix

After applying optimization:
```bash
# Re-run the baseline test
# Compare P50, P90, P99 before and after
```

### Performance Budget Template

```
SLA: API must respond within 2000ms at P99

Budget allocation:
  HTTP Listener overhead:    20ms
  Authentication:           100ms
  Database query:           200ms
  DataWeave transform:       50ms
  External API call:        500ms
  HTTP Response overhead:    20ms
  ──────────────────────────────
  Total budget:             890ms
  Headroom (2000 - 890):   1110ms  (for variance, GC pauses, retries)

If any component exceeds its budget, it's the optimization target.
```

### Gotchas
- **Logger itself adds latency** — logging every request with full payload adds I/O. In production profiling, log timing numbers only (not payload contents). Remove detailed logging after profiling.
- **Profiling changes behavior** — adding timing variables and loggers adds ~1-2ms of overhead per component. For sub-millisecond operations, this overhead skews the results.
- **Cold start skews results** — the first few requests are always slower (JIT compilation, connection pool initialization, class loading). Discard the first 50-100 requests in your analysis.
- **DataWeave compilation** — the first execution of a DataWeave script includes compilation time. Subsequent executions use the cached compiled form. Profile steady-state, not first-run.
- **GC pauses appear as random slowdowns** — if you see occasional extreme outliers (e.g., P99 = 5000ms but P95 = 200ms), it's likely GC. Check GC logs to correlate.
- **Network variability** — downstream API response times vary. Run enough requests (100+) and focus on percentiles, not individual measurements.
- **Anypoint Monitoring has 1-minute aggregation** — you won't see sub-minute variations in the UI. For microsecond-level profiling, use the logging approach.

### Related
- [Thread Pool Component Mapping](../thread-pool-component-mapping/) — understand which pool the bottleneck runs on
- [Thread Dump Reading Guide](../thread-dump-reading-guide/) — correlate profiling with thread behavior
- [Anypoint Monitoring Custom Metrics](../anypoint-monitoring-custom-metrics/) — build production dashboards for profiling data
- [Batch Performance Tuning](../batch-performance-tuning/) — profiling batch jobs specifically
