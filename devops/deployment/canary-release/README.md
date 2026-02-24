## Canary Release
> Percentage-based traffic routing to validate new versions with real production traffic

### When to Use
- You want to validate a new version with a small percentage of production traffic first
- You need to monitor error rates and latency before full rollout
- You want automated rollback if the canary shows degraded performance

### Configuration

**canary-deploy.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="order-api"
ENV="PROD"
NEW_VERSION="$1"
CANARY_PERCENT="${2:-10}"  # Start with 10% traffic
ARTIFACT="target/${APP_NAME}-${NEW_VERSION}-mule-application.jar"

STABLE_APP="${APP_NAME}-stable"
CANARY_APP="${APP_NAME}-canary"

echo "=== Canary Release: v${NEW_VERSION} (${CANARY_PERCENT}% traffic) ==="

# Step 1: Deploy canary version
echo "Deploying canary..."
mvn mule:deploy -B \
    -Dmule.artifact="$ARTIFACT" \
    -Danypoint.connectedApp.clientId="$CONNECTED_APP_ID" \
    -Danypoint.connectedApp.clientSecret="$CONNECTED_APP_SECRET" \
    -Danypoint.connectedApp.grantType=client_credentials \
    -Danypoint.environment="$ENV" \
    -Dcloudhub2.applicationName="$CANARY_APP" \
    -Dcloudhub2.replicas=1 \
    -Dcloudhub2.vCores=0.1

# Step 2: Wait for canary to start
echo "Waiting for canary..."
sleep 60

# Step 3: Configure weighted routing (Flex Gateway or external LB)
# Using Flex Gateway API Instance with weighted backends
cat > /tmp/canary-routing.yaml << EOF
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: ${APP_NAME}-canary-route
spec:
  address: https://api.example.com:443
  services:
    stable:
      address: http://${STABLE_APP}.internal:8081
      weight: $((100 - CANARY_PERCENT))
    canary:
      address: http://${CANARY_APP}.internal:8081
      weight: ${CANARY_PERCENT}
  routes:
    - rules:
        - path: /api/v1/(.*)
          methods: [GET, POST, PUT, DELETE]
EOF

kubectl apply -f /tmp/canary-routing.yaml
echo "Traffic split: ${STABLE_APP}=$((100 - CANARY_PERCENT))% | ${CANARY_APP}=${CANARY_PERCENT}%"

# Step 4: Monitor canary metrics
echo "Monitoring canary for 10 minutes..."
MONITOR_MINUTES=10
for i in $(seq 1 $MONITOR_MINUTES); do
    sleep 60

    # Check canary error rate
    ERROR_RATE=$(curl -s "http://prometheus:9090/api/v1/query" \
        --data-urlencode "query=rate(http_requests_total{app=\"${CANARY_APP}\",status=~\"5..\"}[5m]) / rate(http_requests_total{app=\"${CANARY_APP}\"}[5m]) * 100" \
        | jq -r '.data.result[0].value[1] // "0"')

    # Check canary p95 latency
    P95=$(curl -s "http://prometheus:9090/api/v1/query" \
        --data-urlencode "query=histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{app=\"${CANARY_APP}\"}[5m]))" \
        | jq -r '.data.result[0].value[1] // "0"')

    echo "  Minute $i/$MONITOR_MINUTES: error_rate=${ERROR_RATE}% p95=${P95}s"

    # Auto-rollback if error rate > 5% or p95 > 3s
    if (( $(echo "$ERROR_RATE > 5" | bc -l) )); then
        echo "ERROR: Canary error rate ${ERROR_RATE}% exceeds 5% threshold. Rolling back."
        kubectl delete -f /tmp/canary-routing.yaml
        anypoint-cli-v4 runtime-mgr:application:stop \
            --name "$CANARY_APP" --environment "$ENV"
        exit 1
    fi
done

echo "Canary looks healthy. Proceed with full rollout? (manual step)"
```

**promote-canary.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Gradually increase canary traffic: 10% -> 25% -> 50% -> 100%
for PERCENT in 25 50 75 100; do
    echo "Increasing canary to ${PERCENT}%..."
    # Update weighted routing
    # ... (same kubectl apply with updated weights)
    echo "Monitoring at ${PERCENT}% for 5 minutes..."
    sleep 300
done

echo "Canary promoted to 100%. Updating stable..."
# Deploy canary version as the new stable
# Stop old canary instance
```

### How It Works
1. New version deploys as a separate "canary" application alongside the stable version
2. Weighted routing (via Flex Gateway, Nginx, or an external LB) sends a small percentage of traffic to the canary
3. Automated monitoring checks error rate and latency against defined thresholds
4. If thresholds are breached, traffic is automatically routed back to stable (rollback)
5. If metrics are healthy, traffic percentage is gradually increased until 100%
6. Once at 100%, the canary version becomes the new stable

### Gotchas
- Weighted routing requires an external load balancer or Flex Gateway — CloudHub DLBs do not support weights natively
- Canary monitoring needs real-time metrics (Prometheus, Anypoint Monitoring); batch analytics are too slow
- Database changes must be backward-compatible since both versions run simultaneously
- Canary with very low traffic (e.g., 1%) may not generate statistically significant metrics
- Session affinity (sticky sessions) can skew canary traffic distribution

### Related
- [blue-green](../blue-green/) — Instant switch instead of gradual rollout
- [rolling-update](../rolling-update/) — Update replicas one at a time
- [slo-sli-alerting](../../observability/slo-sli-alerting/) — Define canary thresholds from SLOs
