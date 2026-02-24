## Credential Rotation
> Automated credential rotation with zero-downtime restarts for MuleSoft applications

### When to Use
- Security policy mandates periodic credential rotation (e.g., every 30/60/90 days)
- You need zero-downtime rotation without manual intervention
- You want to automate the full lifecycle: generate, deploy, verify, revoke old

### Configuration

**Dual-credential rotation strategy (Mule XML)**
```xml
<!-- Support two active credentials during rotation window -->
<flow name="authenticate-request-flow">
    <set-variable variableName="primaryKey" value="${api.key.primary}" />
    <set-variable variableName="secondaryKey" value="${api.key.secondary}" />

    <choice doc:name="Validate API Key">
        <when expression="#[attributes.headers['x-api-key'] == vars.primaryKey]">
            <logger message="Authenticated with primary key" level="DEBUG" />
        </when>
        <when expression="#[attributes.headers['x-api-key'] == vars.secondaryKey]">
            <logger message="Authenticated with secondary key (rotation window)" level="WARN" />
        </when>
        <otherwise>
            <raise-error type="APP:UNAUTHORIZED" description="Invalid API key" />
        </otherwise>
    </choice>
</flow>
```

**Rotation script (rotate-credentials.sh)**
```bash
#!/usr/bin/env bash
set -euo pipefail

APP_NAME="order-api-v1"
ENV="PROD"
ORG_ID="$ANYPOINT_ORG_ID"

echo "=== Credential Rotation for $APP_NAME ($ENV) ==="

# Step 1: Generate new credential
NEW_KEY=$(openssl rand -hex 32)
echo "Generated new API key"

# Step 2: Get current primary key (becomes secondary)
CURRENT_PRIMARY=$(anypoint-cli-v4 runtime-mgr:application:describe \
    --name "$APP_NAME" \
    --environment "$ENV" \
    --output json | jq -r '.properties["api.key.primary"]')

# Step 3: Deploy with dual credentials (zero-downtime window)
echo "Deploying with dual credentials..."
anypoint-cli-v4 runtime-mgr:application:modify \
    --name "$APP_NAME" \
    --environment "$ENV" \
    --property "api.key.primary=$NEW_KEY" \
    --property "api.key.secondary=$CURRENT_PRIMARY"

# Step 4: Wait for deployment to complete
echo "Waiting for deployment..."
sleep 60
STATUS=$(anypoint-cli-v4 runtime-mgr:application:describe \
    --name "$APP_NAME" \
    --environment "$ENV" \
    --output json | jq -r '.status')

if [ "$STATUS" != "RUNNING" ]; then
    echo "ERROR: App not running after credential update. Status: $STATUS"
    exit 1
fi

# Step 5: Verify new credential works
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "x-api-key: $NEW_KEY" \
    "https://order-api.example.com/api/v1/health")

if [ "$HTTP_CODE" != "200" ]; then
    echo "ERROR: Health check failed with new credential (HTTP $HTTP_CODE)"
    # Rollback
    anypoint-cli-v4 runtime-mgr:application:modify \
        --name "$APP_NAME" \
        --environment "$ENV" \
        --property "api.key.primary=$CURRENT_PRIMARY" \
        --property "api.key.secondary="
    exit 1
fi

echo "New credential verified. Health check passed."

# Step 6: Update consumers (notify or update their config)
echo "Notifying consumers to update their keys..."
# ... consumer notification logic ...

# Step 7: After grace period, remove old credential
echo "Schedule: Remove secondary key after 24h grace period"
at now + 24 hours <<EOF
anypoint-cli-v4 runtime-mgr:application:modify \
    --name "$APP_NAME" \
    --environment "$ENV" \
    --property "api.key.secondary="
EOF

echo "Rotation complete. New key active, old key valid for 24h."
```

**Cron job for scheduled rotation**
```bash
# /etc/cron.d/mule-credential-rotation
# Rotate credentials on the 1st of every month at 2 AM UTC
0 2 1 * * muleadmin /opt/scripts/rotate-credentials.sh >> /var/log/credential-rotation.log 2>&1
```

**Database credential rotation with Vault**
```hcl
# Vault dynamic database credentials (auto-rotate)
resource "vault_database_secret_backend_role" "mule_app" {
  backend = vault_mount.database.path
  name    = "mule-app-role"
  db_name = vault_database_secret_backend_connection.postgres.name

  creation_statements = [
    "CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';",
    "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO \"{{name}}\";",
  ]

  revocation_statements = [
    "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM \"{{name}}\";",
    "DROP ROLE IF EXISTS \"{{name}}\";",
  ]

  default_ttl = "1h"
  max_ttl     = "24h"
}
```

### How It Works
1. **Dual-credential pattern**: both old and new keys are valid during the rotation window
2. The rotation script generates a new key, promotes it to primary, demotes old to secondary
3. Health check verification ensures the new credential works before completing rotation
4. Automatic rollback if the health check fails after credential update
5. Grace period (24h) allows consumers to update their keys before the old one is revoked
6. Vault dynamic credentials eliminate the rotation problem entirely — credentials are ephemeral

### Gotchas
- CloudHub 2.0 restarts the app when Runtime Manager properties change; plan for brief downtime
- The dual-credential pattern requires application code changes to check both keys
- Consumer notification is the hardest part — maintain a registry of who uses each credential
- Database credential rotation must be coordinated with connection pool refresh
- Always test rotation in DEV/QA before running in production

### Related
- [hashicorp-vault](../hashicorp-vault/) — Dynamic credentials via Vault
- [aws-secrets-manager](../aws-secrets-manager/) — AWS rotation with Lambda
- [rollback-strategies](../../deployment/rollback-strategies/) — Rollback if rotation fails
