## Dev/Sandbox Cost Reduction
> Cut non-production environment costs by 60-70% with scheduled shutdowns, shared sandboxes, and mocking strategies.

### When to Use
- Non-production environments (dev, QA, staging) running 24/7 but only used during business hours
- Each developer has a dedicated CloudHub sandbox consuming vCores around the clock
- Integration testing requires live backend connections that cost money (SaaS API calls, DB instances)
- Looking for quick wins before tackling production cost optimization

### Configuration / Code

#### Cost Impact: Always-On vs Scheduled

| Environment | Workers | vCores | Always-On ($/mo) | Scheduled 10h/day ($/mo) | Savings |
|-------------|---------|--------|-------------------|--------------------------|---------|
| Dev-1 | 4 × 0.2 | 0.8 | $480 | $200 | $280 (58%) |
| Dev-2 | 4 × 0.2 | 0.8 | $480 | $200 | $280 (58%) |
| QA | 6 × 0.2 | 1.2 | $720 | $300 | $420 (58%) |
| Staging | 6 × 0.5 | 3.0 | $1,800 | $540 | $1,260 (70%) |
| **Total** | **20** | **5.8** | **$3,480** | **$1,240** | **$2,240 (64%)** |

*Assumes $600/vCore/mo list price. Scheduled = 10 hours weekdays only (10h × 22 days = 220h / 730h = 30%).*

#### Scheduled Start/Stop with Anypoint CLI

```bash
#!/bin/bash
# scheduled-env-manager.sh
# Run via cron: start at 8 AM, stop at 6 PM (team timezone)

ACTION=$1  # "start" or "stop"
ENVIRONMENT="Sandbox"
APPS=("customer-api-dev" "order-api-dev" "product-api-dev" "inventory-api-dev")

ANYPOINT_USERNAME="${ANYPOINT_USERNAME}"
ANYPOINT_PASSWORD="${ANYPOINT_PASSWORD}"
ANYPOINT_ORG="${ANYPOINT_ORG}"

# Authenticate
anypoint-cli account login --username "$ANYPOINT_USERNAME" --password "$ANYPOINT_PASSWORD"

for APP in "${APPS[@]}"; do
  if [ "$ACTION" == "start" ]; then
    echo "[$(date)] Starting $APP in $ENVIRONMENT..."
    anypoint-cli runtime-mgr cloudhub-application start \
      --environment "$ENVIRONMENT" "$APP"
  elif [ "$ACTION" == "stop" ]; then
    echo "[$(date)] Stopping $APP in $ENVIRONMENT..."
    anypoint-cli runtime-mgr cloudhub-application stop \
      --environment "$ENVIRONMENT" "$APP"
  fi
done

echo "[$(date)] $ACTION complete for all apps in $ENVIRONMENT"
```

#### Cron Schedule

```cron
# Start dev environments at 8 AM EST weekdays
0 8 * * 1-5 /opt/scripts/scheduled-env-manager.sh start >> /var/log/env-manager.log 2>&1

# Stop dev environments at 6 PM EST weekdays
0 18 * * 1-5 /opt/scripts/scheduled-env-manager.sh stop >> /var/log/env-manager.log 2>&1

# Stop everything on Friday evening (catch weekend)
0 19 * * 5 /opt/scripts/scheduled-env-manager.sh stop >> /var/log/env-manager.log 2>&1
```

#### GitHub Actions Alternative

```yaml
name: Manage Dev Environments
on:
  schedule:
    # Start at 8 AM EST (13:00 UTC) weekdays
    - cron: '0 13 * * 1-5'
    # Stop at 6 PM EST (23:00 UTC) weekdays
    - cron: '0 23 * * 1-5'
  workflow_dispatch:
    inputs:
      action:
        description: 'start or stop'
        required: true
        type: choice
        options: [start, stop]

jobs:
  manage-env:
    runs-on: ubuntu-latest
    steps:
      - name: Determine action
        id: action
        run: |
          HOUR=$(date -u +%H)
          if [ "${{ github.event.inputs.action }}" != "" ]; then
            echo "action=${{ github.event.inputs.action }}" >> $GITHUB_OUTPUT
          elif [ "$HOUR" -lt 18 ]; then
            echo "action=start" >> $GITHUB_OUTPUT
          else
            echo "action=stop" >> $GITHUB_OUTPUT
          fi

      - name: Install Anypoint CLI
        run: npm install -g anypoint-cli-v4

      - name: Execute start/stop
        env:
          ANYPOINT_CLIENT_ID: ${{ secrets.ANYPOINT_CLIENT_ID }}
          ANYPOINT_CLIENT_SECRET: ${{ secrets.ANYPOINT_CLIENT_SECRET }}
          ANYPOINT_ORG: ${{ secrets.ANYPOINT_ORG }}
        run: |
          anypoint-cli account login --client_id "$ANYPOINT_CLIENT_ID" --client_secret "$ANYPOINT_CLIENT_SECRET"

          APPS=("customer-api-dev" "order-api-dev" "product-api-dev" "inventory-api-dev")
          for APP in "${APPS[@]}"; do
            anypoint-cli runtime-mgr cloudhub-application ${{ steps.action.outputs.action }} \
              --environment Sandbox "$APP"
          done
```

#### Mocking Strategy — Avoid Runtime During Development

Use MUnit + APIkit mocking to eliminate the need for running backend dependencies:

```xml
<!-- munit-test-with-mock.xml -->
<munit:test name="test-order-creation-with-mocked-backend"
            description="Test order flow without real Salesforce connection">

    <!-- Mock the Salesforce connector -->
    <munit:behavior>
        <munit-tools:mock-when processor="salesforce:create">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="type" whereValue="Order__c" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[output application/json --- {id: "001ABC", success: true}]' />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <!-- Execute the flow -->
    <munit:execution>
        <flow-ref name="create-order-flow" />
    </munit:execution>

    <!-- Verify result -->
    <munit:validation>
        <munit-tools:assert-that expression="#[payload.orderId]" is="#[MunitTools::notNullValue()]" />
    </munit:validation>
</munit:test>
```

#### Shared Sandbox Configuration

Instead of per-developer sandboxes, use a shared environment with path-based isolation:

```
Shared Sandbox Layout:
  /api/v1/dev-alice/customers/*   → Alice's development branch
  /api/v1/dev-bob/customers/*     → Bob's development branch
  /api/v1/qa/customers/*          → QA stable branch
```

### How It Works
1. Audit non-production environments — list all workers running in Sandbox/Design environments and their utilization
2. Implement scheduled start/stop — run dev environments only during business hours (10h/day × 5 days = 29% of 24/7, saving 60-71%)
3. Consolidate per-developer sandboxes into shared environments with path or header-based isolation
4. Replace live backend dependencies with MUnit mocks and API mocking tools (Postman mock servers, WireMock) for local development
5. Use API Designer and DataWeave Playground for design-time work that requires zero runtime vCores
6. Set up alerts for workers accidentally left running outside business hours

### Gotchas
- **Cold start delays** — CloudHub workers take 2-5 minutes to start; developers arriving at 8 AM may wait for environments to come up; consider starting 15 minutes early
- **Shared state conflicts** — multiple developers using the same sandbox can overwrite each other's test data; use per-developer database schemas or record prefixes
- **Anypoint CLI authentication** — scheduled scripts need connected app credentials (client ID/secret), not username/password; rotate secrets according to security policy
- **Scheduled stop kills in-flight requests** — ensure stop scripts check for active processing before terminating; add a drain period for long-running batch jobs
- **CloudHub 2.0 differences** — CH2 uses replicas, not workers; the start/stop CLI commands differ; check `anypoint-cli runtime-mgr ch2-application` syntax
- **Design Center costs** — Design Center environments consume separate entitlements; unused Design Center environments still cost money
- **MUnit mocks drift from reality** — mocked responses can become stale; periodically validate mocks against actual backend responses in a scheduled integration test

### Related
- [vCore Right-Sizing Calculator](../vcore-right-sizing-calculator/) — right-size the workers that remain running
- [API Consolidation Patterns](../api-consolidation-patterns/) — consolidate dev APIs into fewer workers before scheduling
- [License Audit & Renewal Checklist](../license-audit-renewal-checklist/) — include sandbox costs in renewal audit
- [CloudHub 2.0 HPA Autoscaling](../../performance/cloudhub/ch2-hpa-autoscaling/) — auto-scaling for staging environments
