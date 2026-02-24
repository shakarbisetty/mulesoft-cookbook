## API Consolidation Patterns
> Bundle low-traffic APIs into shared workers using a domain multiplexer pattern to save 40-60% on vCore costs.

### When to Use
- Multiple APIs each running on dedicated 0.1 or 0.2 vCore workers with low utilization (<20% CPU)
- Hitting vCore entitlement limits but most workers are idle
- Internal APIs with predictable, low traffic that don't justify isolated deployments
- Cost reduction initiative targeting CloudHub spend without retiring functionality

### Configuration / Code

#### Cost Savings Example

| Metric | Before (Isolated) | After (Consolidated) | Savings |
|--------|-------------------|---------------------|---------|
| APIs | 5 | 5 (same functionality) | — |
| Workers | 5 × 0.2 vCore | 1 × 0.5 vCore | — |
| Total vCores | 1.0 | 0.5 | **50%** |
| Monthly Cost (est.) | $2,400 | $1,200 | **$1,200/mo** |
| Annual Savings | — | — | **$14,400/yr** |

#### Domain Multiplexer Pattern — Mule XML

A single Mule application hosting multiple API specs with path-based routing:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:apikit="http://www.mulesoft.org/schema/mule/mule-apikit"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/http http://www.mulesoft.org/schema/mule/http/current/mule-http.xsd
        http://www.mulesoft.org/schema/mule/mule-apikit http://www.mulesoft.org/schema/mule/mule-apikit/current/mule-apikit.xsd">

    <!-- Shared HTTP Listener on port 8081 -->
    <http:listener-config name="shared-listener"
                          host="0.0.0.0" port="${http.port}" />

    <!-- APIkit Router for Customers API -->
    <apikit:config name="customers-api-config"
                   api="resource::com.example::customers-api::1.0.0::raml::zip::api.raml"
                   outboundHeadersMapName="outboundHeaders"
                   httpStatusVarName="httpStatus" />

    <!-- APIkit Router for Orders API -->
    <apikit:config name="orders-api-config"
                   api="resource::com.example::orders-api::1.0.0::raml::zip::api.raml"
                   outboundHeadersMapName="outboundHeaders"
                   httpStatusVarName="httpStatus" />

    <!-- APIkit Router for Products API -->
    <apikit:config name="products-api-config"
                   api="resource::com.example::products-api::1.0.0::raml::zip::api.raml"
                   outboundHeadersMapName="outboundHeaders"
                   httpStatusVarName="httpStatus" />

    <!-- Customers API Entry Point -->
    <flow name="customers-api-main">
        <http:listener config-ref="shared-listener" path="/api/v1/customers/*" />
        <apikit:router config-ref="customers-api-config" />
    </flow>

    <!-- Orders API Entry Point -->
    <flow name="orders-api-main">
        <http:listener config-ref="shared-listener" path="/api/v1/orders/*" />
        <apikit:router config-ref="orders-api-config" />
    </flow>

    <!-- Products API Entry Point -->
    <flow name="products-api-main">
        <http:listener config-ref="shared-listener" path="/api/v1/products/*" />
        <apikit:router config-ref="products-api-config" />
    </flow>

    <!-- Shared error handler for all APIs -->
    <error-handler name="global-error-handler">
        <on-error-propagate type="APIKIT:BAD_REQUEST">
            <set-payload value='#[output application/json --- {error: "Bad Request", message: error.description}]' />
            <set-variable variableName="httpStatus" value="400" />
        </on-error-propagate>
        <on-error-propagate type="APIKIT:NOT_FOUND">
            <set-payload value='#[output application/json --- {error: "Not Found", message: error.description}]' />
            <set-variable variableName="httpStatus" value="404" />
        </on-error-propagate>
        <on-error-propagate type="ANY">
            <set-payload value='#[output application/json --- {error: "Internal Server Error", message: error.description}]' />
            <set-variable variableName="httpStatus" value="500" />
        </on-error-propagate>
    </error-handler>
</mule>
```

#### API Manager Registration

Each API within the consolidated worker still gets its own API Manager instance for independent policy enforcement:

```bash
# Register each API path as a separate API instance in API Manager
# This preserves per-API rate limiting, SLA tiers, and analytics

# Customers API
anypoint-cli api-mgr api manage \
  --apiVersion "1.0.0" \
  --environment Production \
  --withProxy false \
  --uri "https://my-consolidated-app.us-e1.cloudhub.io/api/v1/customers" \
  "Customers API"

# Orders API
anypoint-cli api-mgr api manage \
  --apiVersion "1.0.0" \
  --environment Production \
  --withProxy false \
  --uri "https://my-consolidated-app.us-e1.cloudhub.io/api/v1/orders" \
  "Orders API"

# Products API
anypoint-cli api-mgr api manage \
  --apiVersion "1.0.0" \
  --environment Production \
  --withProxy false \
  --uri "https://my-consolidated-app.us-e1.cloudhub.io/api/v1/products" \
  "Products API"
```

#### Consolidation Candidate Scoring

```
Consolidation Score = (1 - Avg CPU%) × (1 - Avg Memory%) × Affinity Bonus

Where:
  Avg CPU%       = 7-day average CPU utilization (0.0-1.0)
  Avg Memory%    = 7-day average memory utilization (0.0-1.0)
  Affinity Bonus = 1.5 if APIs share the same domain/team, 1.0 otherwise

Score > 0.6 = Strong candidate for consolidation
Score 0.3-0.6 = Evaluate case by case
Score < 0.3 = Keep isolated
```

### How It Works
1. Identify consolidation candidates — APIs with <20% CPU and <50% memory utilization over a 7-day window
2. Group APIs by domain affinity (same team, same backend systems, same deployment cadence)
3. Sum the memory requirements of all candidate APIs and select a vCore size that fits the combined load with 30% headroom
4. Create a single Mule project with multiple APIkit router configurations, each bound to a distinct base path
5. Register each API path separately in API Manager to preserve independent SLA policies, rate limiting, and analytics
6. Deploy the consolidated application and monitor for 2 weeks — watch for memory pressure and response time degradation
7. Update API consumers with the new base URL (or use a load balancer / API proxy to maintain old URLs)

### Gotchas
- **Blast radius** — one API with a memory leak or infinite loop takes down all co-hosted APIs; only consolidate APIs with similar reliability profiles
- **Shared memory ceiling** — five APIs that each need 400MB of heap cannot fit on a 0.5 vCore (1,500MB) once you add runtime overhead; do the math first
- **Deployment coupling** — updating one API requires redeploying the entire consolidated worker; this means coordinated release windows and shared regression testing
- **Connection pool stacking** — each API's HTTP requesters, DB connectors, and JMS connections consume memory; 5 APIs × 4 connectors × 20 pool size = 400 connections competing for resources
- **Independent scaling is lost** — if one API gets a traffic spike, you scale the entire worker (and all APIs); consider keeping APIs with variable traffic isolated
- **API Manager policy conflicts** — ensure rate-limit policies are configured per-API-instance in API Manager, not per-worker; a global rate limit would be shared across all APIs
- **Log noise** — all APIs write to the same log; use structured logging with an `api-name` field to filter effectively

### Related
- [vCore Right-Sizing Calculator](../vcore-right-sizing-calculator/) — sizing the consolidated worker correctly
- [HTTP Connection Pool Tuning](../../performance/connections/http-connection-pool/) — managing shared connection pools
- [Dev Sandbox Cost Reduction](../dev-sandbox-cost-reduction/) — additional cost savings for non-production
- [CloudHub vCore Sizing Matrix](../../performance/cloudhub/vcore-sizing-matrix/) — performance baselines per vCore tier
