## API Manager Automation
> Script API instance creation, policy application, and SLA tier setup

### When to Use
- You need to automate API governance as part of CI/CD
- You want consistent policy application across environments
- You need to manage SLA tiers and client application approvals programmatically

### Configuration

**setup-api-instance.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

API_NAME="Order API"
API_VERSION="1.0.0"
ASSET_ID="order-api"
ENV="PROD"

echo "=== API Manager Setup for $API_NAME v$API_VERSION ==="

# Step 1: Create API instance
echo "Creating API instance..."
API_INSTANCE=$(anypoint-cli-v4 api-mgr:api:create \
    --name "$API_NAME" \
    --version "$API_VERSION" \
    --assetId "$ASSET_ID" \
    --environment "$ENV" \
    --endpoint "https://order-api.us-e2.cloudhub.io/api/v1" \
    --endpointType "http" \
    --output json)

API_ID=$(echo "$API_INSTANCE" | jq -r '.id')
echo "API Instance ID: $API_ID"

# Step 2: Apply policies
echo "Applying rate limiting policy..."
anypoint-cli-v4 api-mgr:policy:apply \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --policyId "rate-limiting" \
    --config '{
        "rateLimits": [{
            "maximumRequests": 1000,
            "timePeriodInMilliseconds": 60000
        }],
        "clusterizable": true,
        "exposeHeaders": true
    }'

echo "Applying JWT validation policy..."
anypoint-cli-v4 api-mgr:policy:apply \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --policyId "jwt-validation" \
    --config '{
        "jwtOrigin": "httpBearerAuthenticationHeader",
        "jwtKeyOrigin": "jwks",
        "jwksUrl": "https://auth.example.com/.well-known/jwks.json",
        "jwksServiceConnectionTimeout": 10000,
        "skipClientIdValidation": false,
        "clientIdExpression": "#[vars.claimSet.client_id]",
        "validateAudClaim": true,
        "mandatoryAudClaim": true,
        "supportedAudiences": "order-api",
        "mandatoryExpClaim": true,
        "mandatoryNbfClaim": false
    }'

echo "Applying CORS policy..."
anypoint-cli-v4 api-mgr:policy:apply \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --policyId "cors" \
    --config '{
        "allowedOrigins": ["https://app.example.com"],
        "allowedMethods": ["GET", "POST", "PUT", "DELETE"],
        "allowedHeaders": ["Content-Type", "Authorization", "x-correlation-id"],
        "exposedHeaders": ["x-ratelimit-remaining"],
        "maxAge": 3600,
        "supportCredentials": true
    }'

# Step 3: Create SLA tiers
echo "Creating SLA tiers..."
anypoint-cli-v4 api-mgr:sla:create \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --name "Bronze" \
    --description "100 requests per minute" \
    --autoApprove true \
    --limits '[{"maximumRequests": 100, "timePeriodInMilliseconds": 60000}]'

anypoint-cli-v4 api-mgr:sla:create \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --name "Silver" \
    --description "500 requests per minute" \
    --autoApprove false \
    --limits '[{"maximumRequests": 500, "timePeriodInMilliseconds": 60000}]'

anypoint-cli-v4 api-mgr:sla:create \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --name "Gold" \
    --description "2000 requests per minute" \
    --autoApprove false \
    --limits '[{"maximumRequests": 2000, "timePeriodInMilliseconds": 60000}]'

# Step 4: Apply SLA-based rate limiting
echo "Applying SLA-based rate limiting..."
anypoint-cli-v4 api-mgr:policy:apply \
    --apiId "$API_ID" \
    --environment "$ENV" \
    --policyId "rate-limiting-sla-based" \
    --config '{
        "clusterizable": true,
        "exposeHeaders": true
    }'

echo "API Manager setup complete for $API_NAME"
echo "API ID: $API_ID"
```

**List and audit policies**
```bash
# List all policies on an API
anypoint-cli-v4 api-mgr:policy:list \
    --apiId "$API_ID" \
    --environment "PROD" \
    --output table

# List all API instances
anypoint-cli-v4 api-mgr:api:list \
    --environment "PROD" \
    --output json | jq '.[] | {id, name: .assetId, version: .assetVersion, status}'

# List SLA tiers
anypoint-cli-v4 api-mgr:sla:list \
    --apiId "$API_ID" \
    --environment "PROD" \
    --output table

# List client applications with contracts
anypoint-cli-v4 api-mgr:contract:list \
    --apiId "$API_ID" \
    --environment "PROD" \
    --output json | jq '.[] | {clientApp: .applicationName, tier: .tierName, status}'
```

### How It Works
1. API instances link Exchange assets to deployed CloudHub applications
2. Policies are applied in order; they execute as an inbound/outbound chain
3. SLA tiers define rate limits per client application (requires client ID enforcement)
4. Client applications request contracts with specific SLA tiers (auto-approve or manual)
5. All settings are scriptable for environment promotion: DEV policies → QA → PROD

### Gotchas
- Policy configuration JSON must exactly match the policy schema; validate against docs
- Policy order matters — authentication policies should come before authorization
- Removing and re-applying policies can cause brief gaps in enforcement
- API autodiscovery (`api.id` property) must match the API instance ID for policies to apply
- SLA-based rate limiting requires the `client-id-enforcement` policy to be active

### Related
- [cli-v4-recipes](../cli-v4-recipes/) — General CLI commands
- [exchange-publishing](../exchange-publishing/) — Publish API specs to Exchange
- [org-management-scripts](../org-management-scripts/) — Org-level management
