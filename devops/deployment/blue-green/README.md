## Blue-Green Deployment
> Blue-green deployment on CloudHub 2.0 with instant rollback capability

### When to Use
- You need zero-downtime deployments for production APIs
- You want instant rollback by switching traffic back to the previous version
- You require pre-production validation of the new version before routing traffic

### Configuration

**blue-green-deploy.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="order-api"
ENV="PROD"
NEW_VERSION="$1"  # e.g., "2.1.0"
ARTIFACT="target/${APP_NAME}-${NEW_VERSION}-mule-application.jar"

BLUE_APP="${APP_NAME}-blue"
GREEN_APP="${APP_NAME}-green"

# Determine which slot is active
ACTIVE_APP=$(anypoint-cli-v4 runtime-mgr:application:describe \
    --name "$BLUE_APP" --environment "$ENV" --output json 2>/dev/null | jq -r '.status' || echo "NOT_FOUND")

if [ "$ACTIVE_APP" == "RUNNING" ]; then
    DEPLOY_TO="$GREEN_APP"
    ACTIVE="$BLUE_APP"
else
    DEPLOY_TO="$BLUE_APP"
    ACTIVE="$GREEN_APP"
fi

echo "Active: $ACTIVE | Deploying to: $DEPLOY_TO"

# Step 1: Deploy new version to inactive slot
echo "Deploying v${NEW_VERSION} to ${DEPLOY_TO}..."
mvn mule:deploy -B \
    -Dmule.artifact="$ARTIFACT" \
    -Danypoint.connectedApp.clientId="$CONNECTED_APP_ID" \
    -Danypoint.connectedApp.clientSecret="$CONNECTED_APP_SECRET" \
    -Danypoint.connectedApp.grantType=client_credentials \
    -Danypoint.environment="$ENV" \
    -Dcloudhub2.applicationName="$DEPLOY_TO" \
    -Dcloudhub2.replicas=2 \
    -Dcloudhub2.vCores=0.2

# Step 2: Wait for deployment and health check
echo "Waiting for ${DEPLOY_TO} to become healthy..."
for i in $(seq 1 30); do
    STATUS=$(anypoint-cli-v4 runtime-mgr:application:describe \
        --name "$DEPLOY_TO" --environment "$ENV" --output json | jq -r '.status')
    if [ "$STATUS" == "RUNNING" ]; then
        break
    fi
    echo "  Status: $STATUS (attempt $i/30)"
    sleep 10
done

if [ "$STATUS" != "RUNNING" ]; then
    echo "ERROR: ${DEPLOY_TO} did not start. Aborting."
    exit 1
fi

# Step 3: Smoke test the new version
echo "Running smoke tests against ${DEPLOY_TO}..."
HEALTH=$(curl -s -o /dev/null -w "%{http_code}" \
    "https://${DEPLOY_TO}.us-e2.cloudhub.io/api/v1/health")

if [ "$HEALTH" != "200" ]; then
    echo "ERROR: Smoke test failed (HTTP ${HEALTH}). Rolling back."
    anypoint-cli-v4 runtime-mgr:application:stop \
        --name "$DEPLOY_TO" --environment "$ENV"
    exit 1
fi

# Step 4: Switch DLB/DNS to new version
echo "Switching traffic to ${DEPLOY_TO}..."
# Update DLB mapping or DNS CNAME
anypoint-cli-v4 cloudhub:load-balancer:mappings:update \
    --name "prod-dlb" \
    --inputUri "api.example.com" \
    --appName "$DEPLOY_TO" \
    --appUri "/"

echo "Traffic switched to ${DEPLOY_TO} (v${NEW_VERSION})"

# Step 5: Keep old version running for quick rollback
echo "Previous version (${ACTIVE}) kept running for rollback."
echo "Run 'bash rollback.sh' to switch back."
```

**rollback.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Rolling back to previous version..."

# Swap DLB mapping back
CURRENT=$(anypoint-cli-v4 cloudhub:load-balancer:mappings:describe \
    --name "prod-dlb" --output json | jq -r '.appName')

if [ "$CURRENT" == "order-api-blue" ]; then
    ROLLBACK_TO="order-api-green"
else
    ROLLBACK_TO="order-api-blue"
fi

anypoint-cli-v4 cloudhub:load-balancer:mappings:update \
    --name "prod-dlb" \
    --inputUri "api.example.com" \
    --appName "$ROLLBACK_TO" \
    --appUri "/"

echo "Rolled back to ${ROLLBACK_TO}. Traffic restored."
```

### How It Works
1. Two identical app slots (blue and green) run on CloudHub 2.0
2. New version deploys to the inactive slot while the active slot continues serving traffic
3. Smoke tests validate the new version before any traffic switch
4. DLB or DNS CNAME update routes all traffic to the new slot instantly
5. The old version remains running for immediate rollback (just re-point the DLB)
6. After validation period, the old version can be stopped to free resources

### Gotchas
- Both slots consume vCores during the deployment window — budget for 2x resources temporarily
- DLB mapping updates take 1-2 minutes to propagate; clients may see brief inconsistency
- Database schema changes must be backward-compatible (both versions run simultaneously)
- Session state is not shared between blue and green — use external session store
- CloudHub 2.0 application names must be globally unique; use consistent naming

### Related
- [canary-release](../canary-release/) — Gradual traffic shift instead of instant switch
- [rolling-update](../rolling-update/) — Rolling updates without dual slots
- [rollback-strategies](../rollback-strategies/) — Automated rollback patterns
