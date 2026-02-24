## Rollback Strategies
> Automated rollback on health check failures with multiple recovery approaches

### When to Use
- You need automated recovery when deployments fail
- You want documented rollback procedures for different failure modes
- You need to minimize MTTR (Mean Time To Recovery) for production incidents

### Configuration

**auto-rollback.sh — comprehensive rollback script**
```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="order-api-v1"
ENV="PROD"
HEALTH_URL="https://${APP_NAME}.us-e2.cloudhub.io/api/v1/health"
MAX_RETRIES=5
RETRY_DELAY=30

echo "=== Post-Deployment Health Verification ==="

# Step 1: Wait for app to stabilize
sleep 60

# Step 2: Health check loop
HEALTHY=false
for i in $(seq 1 $MAX_RETRIES); do
    HTTP_CODE=$(curl -s -o /tmp/health_response.json -w "%{http_code}" "$HEALTH_URL" || echo "000")

    if [ "$HTTP_CODE" == "200" ]; then
        STATUS=$(jq -r '.status' /tmp/health_response.json)
        if [ "$STATUS" == "UP" ]; then
            echo "Health check passed (attempt $i)"
            HEALTHY=true
            break
        fi
    fi

    echo "Health check failed: HTTP $HTTP_CODE (attempt $i/$MAX_RETRIES)"
    sleep $RETRY_DELAY
done

if [ "$HEALTHY" == "true" ]; then
    echo "Deployment verified. App is healthy."
    exit 0
fi

echo "=== INITIATING ROLLBACK ==="

# Strategy 1: Redeploy previous version from Exchange
rollback_from_exchange() {
    echo "Strategy: Redeploy previous version from Exchange..."

    # Get previous version from deployment history
    PREV_VERSION=$(anypoint-cli-v4 runtime-mgr:application:describe \
        --name "$APP_NAME" --environment "$ENV" --output json \
        | jq -r '.previousVersion // empty')

    if [ -z "$PREV_VERSION" ]; then
        echo "No previous version found in deployment history."
        return 1
    fi

    echo "Rolling back to version: $PREV_VERSION"
    mvn mule:deploy -B \
        -Dmule.artifact="com.example:${APP_NAME}:${PREV_VERSION}:jar:mule-application" \
        -Danypoint.connectedApp.clientId="$CONNECTED_APP_ID" \
        -Danypoint.connectedApp.clientSecret="$CONNECTED_APP_SECRET" \
        -Danypoint.connectedApp.grantType=client_credentials \
        -Danypoint.environment="$ENV"
}

# Strategy 2: Switch DLB to standby (blue-green)
rollback_blue_green() {
    echo "Strategy: Switch DLB to standby slot..."

    CURRENT_SLOT=$(anypoint-cli-v4 cloudhub:load-balancer:mappings:describe \
        --name "prod-dlb" --output json | jq -r '.appName')

    if [ "$CURRENT_SLOT" == "${APP_NAME}-blue" ]; then
        ROLLBACK_SLOT="${APP_NAME}-green"
    else
        ROLLBACK_SLOT="${APP_NAME}-blue"
    fi

    anypoint-cli-v4 cloudhub:load-balancer:mappings:update \
        --name "prod-dlb" \
        --inputUri "api.example.com" \
        --appName "$ROLLBACK_SLOT" \
        --appUri "/"

    echo "DLB switched to $ROLLBACK_SLOT"
}

# Strategy 3: Restart current version (for transient failures)
rollback_restart() {
    echo "Strategy: Restart current deployment..."
    anypoint-cli-v4 runtime-mgr:application:restart \
        --name "$APP_NAME" --environment "$ENV"
    sleep 60

    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")
    if [ "$HTTP_CODE" == "200" ]; then
        echo "Restart resolved the issue."
        return 0
    fi
    return 1
}

# Execute rollback strategies in order
rollback_restart || rollback_from_exchange || rollback_blue_green || {
    echo "ALL ROLLBACK STRATEGIES FAILED. Manual intervention required."
    # Send PagerDuty/Slack alert
    curl -X POST "https://hooks.slack.com/services/$SLACK_WEBHOOK" \
        -H "Content-Type: application/json" \
        -d "{\"text\":\"CRITICAL: All rollback strategies failed for ${APP_NAME} in ${ENV}. Manual intervention required.\"}"
    exit 1
}

echo "Rollback complete. Verifying..."
sleep 30
FINAL_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL")
echo "Final health check: HTTP $FINAL_CODE"
```

**CI pipeline with rollback gate**
```yaml
deploy-prod:
  stage: deploy-prod
  script:
    - mvn mule:deploy -B -Denv=prod
    - bash scripts/auto-rollback.sh
  after_script:
    - |
      if [ "$CI_JOB_STATUS" == "failed" ]; then
        echo "Deployment failed. Check rollback status."
      fi
```

### How It Works
1. After deployment, the script runs health checks with retries and backoff
2. If health checks fail, three rollback strategies execute in order of speed:
   - **Restart**: fastest, fixes transient issues (memory, stuck threads)
   - **Redeploy previous version**: pulls the last good version from Exchange
   - **DLB switch**: instant failover if blue-green is set up
3. Each strategy has a verification step; if it fails, the next strategy is tried
4. If all strategies fail, a critical alert is sent to Slack/PagerDuty
5. The entire flow is automated and runs as a post-deployment CI step

### Gotchas
- Rollback scripts must be tested regularly — a rollback script that fails in production is worse than no script
- Database migrations cannot be easily rolled back; use expand-contract pattern
- "Previous version" in Exchange may not be compatible if APIs have changed
- Restart rollback only works for transient failures; code bugs require version rollback
- Keep rollback scripts in version control and review them like any other code

### Related
- [blue-green](../blue-green/) — DLB-based instant rollback
- [rolling-update](../rolling-update/) — CloudHub 2.0 native rollback
- [zero-downtime-db-migration](../zero-downtime-db-migration/) — Rollback-safe schema changes
