## Anypoint CLI v4 Recipes
> Common CLI commands for deploy, start, stop, logs, and application management

### When to Use
- You need quick command-line access to Anypoint Platform operations
- You want to script deployments and management tasks outside of Maven
- You need to troubleshoot running applications via logs and status checks

### Configuration

**Authentication setup**
```bash
# Install CLI v4
npm install -g @mulesoft/anypoint-cli-v4

# Login with Connected App (recommended for scripts)
export ANYPOINT_CLIENT_ID="your-connected-app-id"
export ANYPOINT_CLIENT_SECRET="your-connected-app-secret"
export ANYPOINT_ORG_ID="your-org-id"

# Or login interactively
anypoint-cli-v4 account:login
```

**Application lifecycle commands**
```bash
# Deploy a new application to CloudHub 2.0
anypoint-cli-v4 runtime-mgr:application:deploy \
    --name "order-api-v1" \
    --environment "DEV" \
    --target "us-east-2" \
    --replicas 2 \
    --vCores 0.1 \
    --artifact "target/order-api-1.0.0-mule-application.jar" \
    --property "env=DEV" \
    --property "api.id=12345"

# Check application status
anypoint-cli-v4 runtime-mgr:application:describe \
    --name "order-api-v1" \
    --environment "DEV" \
    --output json | jq '{status, replicas, lastUpdateTime}'

# List all applications in an environment
anypoint-cli-v4 runtime-mgr:application:list \
    --environment "PROD" \
    --output table

# View application logs (tail)
anypoint-cli-v4 runtime-mgr:application:logs \
    --name "order-api-v1" \
    --environment "DEV" \
    --tail 100

# Download logs
anypoint-cli-v4 runtime-mgr:application:download-logs \
    --name "order-api-v1" \
    --environment "DEV" \
    --output logs/order-api.log

# Restart application
anypoint-cli-v4 runtime-mgr:application:restart \
    --name "order-api-v1" \
    --environment "PROD"

# Stop application
anypoint-cli-v4 runtime-mgr:application:stop \
    --name "order-api-v1" \
    --environment "DEV"

# Start application
anypoint-cli-v4 runtime-mgr:application:start \
    --name "order-api-v1" \
    --environment "DEV"

# Delete application
anypoint-cli-v4 runtime-mgr:application:delete \
    --name "order-api-v1" \
    --environment "DEV"

# Modify application properties (triggers restart)
anypoint-cli-v4 runtime-mgr:application:modify \
    --name "order-api-v1" \
    --environment "PROD" \
    --property "feature.new-flow.enabled=true" \
    --property "api.timeout=15000"

# Scale replicas
anypoint-cli-v4 runtime-mgr:application:modify \
    --name "order-api-v1" \
    --environment "PROD" \
    --replicas 4
```

**Useful scripts**
```bash
# List all unhealthy apps across environments
for ENV in DEV QA PROD; do
    echo "=== $ENV ==="
    anypoint-cli-v4 runtime-mgr:application:list \
        --environment "$ENV" --output json \
        | jq -r '.[] | select(.status != "RUNNING") | "\(.name): \(.status)"'
done

# Bulk restart all apps in an environment
anypoint-cli-v4 runtime-mgr:application:list \
    --environment "DEV" --output json \
    | jq -r '.[].name' \
    | while read APP; do
        echo "Restarting $APP..."
        anypoint-cli-v4 runtime-mgr:application:restart \
            --name "$APP" --environment "DEV"
    done
```

### How It Works
1. The CLI authenticates using Connected App credentials (environment variables or login)
2. Commands follow a `resource:action` pattern: `runtime-mgr:application:deploy`
3. Output formats include `json`, `table`, and `default` for different use cases
4. Property modifications trigger application restarts on CloudHub 2.0
5. The CLI wraps the Anypoint Platform REST API — anything in the API can be scripted

### Gotchas
- Connected App needs appropriate scopes: `CloudHub Developer`, `Read Applications`, etc.
- The `--output json` flag is essential for scripting; default output is human-readable but hard to parse
- `application:modify` with `--property` overwrites ALL properties; pass all existing props too
- Log downloads can be large; use `--tail` for recent entries or time-range filters
- CLI v4 is a separate npm package from the older CLI v3; commands may differ

### Related
- [api-manager-automation](../api-manager-automation/) — Automate API Manager setup
- [exchange-publishing](../exchange-publishing/) — Publish assets from CLI
- [org-management-scripts](../org-management-scripts/) — Org-level management
