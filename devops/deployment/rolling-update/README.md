## Rolling Update
> CloudHub 2.0 multi-replica rolling updates with health check gates

### When to Use
- Your app runs multiple replicas on CloudHub 2.0
- You want zero-downtime deploys without managing blue-green slots
- You accept that both old and new versions coexist briefly during the rollout

### Configuration

**pom.xml — CloudHub 2.0 deployment with rolling strategy**
```xml
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <version>4.2.0</version>
    <configuration>
        <cloudhub2Deployment>
            <uri>https://anypoint.mulesoft.com</uri>
            <connectedAppClientId>${connected.app.clientId}</connectedAppClientId>
            <connectedAppClientSecret>${connected.app.clientSecret}</connectedAppClientSecret>
            <connectedAppGrantType>client_credentials</connectedAppGrantType>
            <environment>${deploy.environment}</environment>
            <target>${cloudhub2.target}</target>
            <replicas>${cloudhub2.replicas}</replicas>
            <vCores>${cloudhub2.vCores}</vCores>
            <deploymentSettings>
                <updateStrategy>rolling</updateStrategy>
                <forwardSslSession>true</forwardSslSession>
                <lastMileSecurity>true</lastMileSecurity>
                <generateDefaultPublicUrl>true</generateDefaultPublicUrl>
            </deploymentSettings>
        </cloudhub2Deployment>
    </configuration>
</plugin>
```

**Health check endpoint (src/main/mule/health.xml)**
```xml
<flow name="health-check-flow">
    <http:listener path="/health" method="GET"
        config-ref="HTTP_Listener_Config" />

    <try>
        <!-- Check database connectivity -->
        <db:select config-ref="Database_Config">
            <db:sql>SELECT 1</db:sql>
        </db:select>

        <!-- Check downstream API -->
        <http:request method="GET"
            config-ref="Downstream_Config"
            path="/health"
            responseTimeout="5000" />

        <set-payload value='#[output application/json --- {
            "status": "UP",
            "version": p("app.version"),
            "timestamp": now(),
            "checks": {
                "database": "UP",
                "downstream": "UP"
            }
        }]' />

    <error-handler>
        <on-error-continue>
            <set-variable variableName="httpStatus" value="503" />
            <set-payload value='#[output application/json --- {
                "status": "DOWN",
                "version": p("app.version"),
                "timestamp": now(),
                "error": error.description
            }]' />
        </on-error-continue>
    </error-handler>
    </try>

    <set-variable variableName="httpStatus"
        value="#[if (payload.status == 'UP') 200 else 503]" />
</flow>
```

**rolling-deploy.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="order-api-v1"
ENV="PROD"
REPLICAS=3

echo "Starting rolling deployment of ${APP_NAME}..."

mvn mule:deploy -B \
    -Ddeploy.environment="$ENV" \
    -Dcloudhub2.replicas="$REPLICAS" \
    -Dcloudhub2.vCores=0.2

# Monitor rolling update progress
echo "Monitoring deployment..."
for i in $(seq 1 60); do
    STATUS=$(anypoint-cli-v4 runtime-mgr:application:describe \
        --name "$APP_NAME" --environment "$ENV" --output json)

    RUNNING=$(echo "$STATUS" | jq -r '.replicas.running // 0')
    DESIRED=$(echo "$STATUS" | jq -r '.replicas.desired // 0')
    DEPLOY_STATUS=$(echo "$STATUS" | jq -r '.status')

    echo "  [$i] Status: $DEPLOY_STATUS | Replicas: $RUNNING/$DESIRED"

    if [ "$DEPLOY_STATUS" == "RUNNING" ] && [ "$RUNNING" == "$DESIRED" ]; then
        echo "Rolling deployment complete. All $DESIRED replicas running."
        exit 0
    fi

    sleep 10
done

echo "WARNING: Deployment did not complete within 10 minutes."
exit 1
```

### How It Works
1. CloudHub 2.0 rolling update replaces one replica at a time
2. Each new replica must pass health checks before the next old replica is terminated
3. The load balancer automatically routes traffic only to healthy replicas
4. During the rollout, both old and new versions serve traffic simultaneously
5. If a new replica fails health checks, the rollout pauses (no more old replicas are terminated)

### Gotchas
- Rolling updates require at least 2 replicas; single-replica apps experience brief downtime
- Both versions run simultaneously — API contracts must be backward-compatible
- Database schema changes need the expand-contract pattern to support both versions
- Health checks should verify dependencies (DB, downstream APIs), not just return 200
- CloudHub 2.0 manages the rolling strategy automatically; you cannot control the order

### Related
- [blue-green](../blue-green/) — No version mixing during deployment
- [canary-release](../canary-release/) — Controlled traffic split
- [zero-downtime-db-migration](../zero-downtime-db-migration/) — Schema changes during rolling updates
