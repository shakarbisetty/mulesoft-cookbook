## Organization Management Scripts
> Bulk provision Business Groups, environments, roles, and Connected Apps

### When to Use
- You need to set up a new Anypoint organization from scratch
- You want to replicate org structure across multiple tenants (prod, sandbox)
- You need bulk user and role provisioning for large teams

### Configuration

**bootstrap-org.sh — full organization setup**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Anypoint Organization Bootstrap ==="

# Get access token
TOKEN=$(curl -s -X POST "https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token" \
    -H "Content-Type: application/json" \
    -d "{
        \"grant_type\": \"client_credentials\",
        \"client_id\": \"$CONNECTED_APP_CLIENT_ID\",
        \"client_secret\": \"$CONNECTED_APP_CLIENT_SECRET\"
    }" | jq -r '.access_token')

ROOT_ORG="$ANYPOINT_ORG_ID"

# Step 1: Create Business Groups
echo "Creating Business Groups..."
BG_CONFIG='[
    {"name": "Integration", "ownerName": "integration-team"},
    {"name": "API Products", "ownerName": "api-team"},
    {"name": "B2B", "ownerName": "b2b-team"},
    {"name": "Internal Tools", "ownerName": "internal-team"}
]'

echo "$BG_CONFIG" | jq -c '.[]' | while read BG; do
    BG_NAME=$(echo "$BG" | jq -r '.name')
    echo "  Creating BG: $BG_NAME"

    BG_ID=$(curl -s -X POST \
        "https://anypoint.mulesoft.com/accounts/api/organizations/${ROOT_ORG}/environments" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$BG_NAME\",
            \"parentOrganizationId\": \"$ROOT_ORG\",
            \"entitlements\": {
                \"vCoresProduction\": {\"assigned\": 2},
                \"vCoresSandbox\": {\"assigned\": 2}
            }
        }" | jq -r '.id')

    echo "    BG ID: $BG_ID"

    # Step 2: Create environments for each BG
    for ENV_TYPE in DEV QA STAGING PROD; do
        case $ENV_TYPE in
            PROD) TYPE="production" ;;
            *) TYPE="sandbox" ;;
        esac

        echo "    Creating env: $ENV_TYPE ($TYPE)"
        curl -s -X POST \
            "https://anypoint.mulesoft.com/accounts/api/organizations/${BG_ID}/environments" \
            -H "Authorization: Bearer $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"name\": \"$ENV_TYPE\", \"type\": \"$TYPE\"}" > /dev/null
    done
done

# Step 3: Create Connected Apps
echo "Creating Connected Apps..."
APPS='[
    {"name": "CI/CD Pipeline", "scopes": ["CloudHub Developer"]},
    {"name": "Monitoring", "scopes": ["Read Applications", "Read Servers"]},
    {"name": "API Governance", "scopes": ["Manage APIs", "Manage Policies"]}
]'

echo "$APPS" | jq -c '.[]' | while read APP; do
    APP_NAME=$(echo "$APP" | jq -r '.name')
    echo "  Creating Connected App: $APP_NAME"

    curl -s -X POST \
        "https://anypoint.mulesoft.com/accounts/api/connectedApplications" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"clientName\": \"$APP_NAME\",
            \"grantTypes\": [\"client_credentials\"],
            \"audience\": \"internal\"
        }" > /dev/null
done

# Step 4: Create custom roles
echo "Creating custom roles..."
ROLES='[
    {"name": "MuleSoft Developer", "description": "Can deploy and manage applications in sandbox"},
    {"name": "MuleSoft Operations", "description": "Can manage applications in all environments"},
    {"name": "API Designer", "description": "Can create and publish API specs"}
]'

echo "$ROLES" | jq -c '.[]' | while read ROLE; do
    ROLE_NAME=$(echo "$ROLE" | jq -r '.name')
    ROLE_DESC=$(echo "$ROLE" | jq -r '.description')
    echo "  Creating role: $ROLE_NAME"

    curl -s -X POST \
        "https://anypoint.mulesoft.com/accounts/api/organizations/${ROOT_ORG}/roles" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"name\": \"$ROLE_NAME\", \"description\": \"$ROLE_DESC\"}" > /dev/null
done

echo "Organization bootstrap complete."
```

**bulk-user-provision.sh**
```bash
#!/usr/bin/env bash
set -euo pipefail

# CSV format: email,firstName,lastName,role
USER_CSV="$1"

while IFS=',' read -r EMAIL FIRST LAST ROLE; do
    [[ "$EMAIL" == "email" ]] && continue  # Skip header

    echo "Inviting $EMAIL as $ROLE..."
    curl -s -X POST \
        "https://anypoint.mulesoft.com/accounts/api/organizations/${ANYPOINT_ORG_ID}/invites" \
        -H "Authorization: Bearer $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"email\": \"$EMAIL\",
            \"firstName\": \"$FIRST\",
            \"lastName\": \"$LAST\",
            \"roleGroupId\": \"$ROLE\"
        }" > /dev/null

done < "$USER_CSV"

echo "User provisioning complete."
```

**audit-org.sh — organization audit report**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Organization Audit Report ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# List all BGs
echo -e "\n--- Business Groups ---"
curl -s "https://anypoint.mulesoft.com/accounts/api/organizations/${ANYPOINT_ORG_ID}/hierarchy" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.subOrganizations[] | "  \(.name) (ID: \(.id))"'

# List all environments per BG
echo -e "\n--- Environments ---"
curl -s "https://anypoint.mulesoft.com/accounts/api/organizations/${ANYPOINT_ORG_ID}/environments" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.data[] | "  \(.name) (\(.type)) - \(.organizationId)"'

# Count Connected Apps
echo -e "\n--- Connected Apps ---"
APPS=$(curl -s "https://anypoint.mulesoft.com/accounts/api/connectedApplications" \
    -H "Authorization: Bearer $TOKEN" | jq '.total')
echo "  Total: $APPS"

# List users
echo -e "\n--- Users ---"
curl -s "https://anypoint.mulesoft.com/accounts/api/organizations/${ANYPOINT_ORG_ID}/members" \
    -H "Authorization: Bearer $TOKEN" | jq -r '.data[] | "  \(.firstName) \(.lastName) (\(.email))"'

echo -e "\nAudit complete."
```

### How It Works
1. Scripts use the Anypoint Platform REST API with Connected App OAuth2 tokens
2. Business Groups are created hierarchically under the root organization
3. Environments are provisioned per BG with appropriate types (sandbox vs. production)
4. Connected Apps are scoped to specific roles and environments
5. User provisioning sends invitations via email with pre-assigned roles

### Gotchas
- Org Admin scope is required on the Connected App for BG and environment management
- Business Group names must be unique within the parent organization
- Entitlements (vCores, VPCs) are allocated from the parent; you cannot over-allocate
- Deleting a BG is destructive and cannot be undone — deployed apps and APIs are lost
- User invitations expire after 7 days; re-invite if not accepted

### Related
- [cli-v4-recipes](../cli-v4-recipes/) — CLI-based operations
- [api-manager-automation](../api-manager-automation/) — API governance setup
- [terraform-anypoint](../../infrastructure/terraform-anypoint/) — Terraform for org management
