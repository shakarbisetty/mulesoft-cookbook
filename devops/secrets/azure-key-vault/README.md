## Azure Key Vault for MuleSoft
> Fetch secrets from Azure Key Vault using managed identity authentication

### When to Use
- Your MuleSoft apps integrate with Azure services
- You use Azure Managed Identity to avoid credential management
- You need centralized secret, key, and certificate management

### Configuration

**pom.xml — Azure Identity SDK**
```xml
<dependency>
    <groupId>com.azure</groupId>
    <artifactId>azure-identity</artifactId>
    <version>1.11.0</version>
</dependency>
<dependency>
    <groupId>com.azure</groupId>
    <artifactId>azure-security-keyvault-secrets</artifactId>
    <version>4.7.0</version>
</dependency>
```

**src/main/mule/azure-keyvault-flow.xml**
```xml
<flow name="azure-keyvault-lookup-flow">
    <!-- Call Azure Key Vault REST API with managed identity token -->
    <http:request method="GET"
        config-ref="Azure_KeyVault_Config"
        path="/secrets/{secretName}"
        doc:name="Get Secret">
        <http:uri-params>
            #[{ "secretName": vars.secretName }]
        </http:uri-params>
        <http:query-params>
            #[{ "api-version": "7.4" }]
        </http:query-params>
        <http:headers>
            #[{ "Authorization": "Bearer " ++ vars.azureToken }]
        </http:headers>
    </http:request>

    <set-variable variableName="secretValue"
        value="#[payload.value]"
        doc:name="Extract Secret Value" />
</flow>

<!-- Token acquisition flow (managed identity) -->
<flow name="get-azure-token-flow">
    <http:request method="GET"
        url="http://169.254.169.254/metadata/identity/oauth2/token"
        doc:name="Get MI Token">
        <http:query-params>
            #[{
                "api-version": "2019-08-01",
                "resource": "https://vault.azure.net"
            }]
        </http:query-params>
        <http:headers>
            #[{ "Metadata": "true" }]
        </http:headers>
    </http:request>

    <set-variable variableName="azureToken"
        value="#[payload.access_token]"
        doc:name="Store Token" />
</flow>
```

**Startup script for secret injection**
```bash
#!/usr/bin/env bash
set -euo pipefail

VAULT_NAME="mulesoft-${ENV}-kv"
VAULT_URL="https://${VAULT_NAME}.vault.azure.net"

# Get token using managed identity
TOKEN=$(curl -s -H "Metadata: true" \
    "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2019-08-01&resource=https://vault.azure.net" \
    | jq -r '.access_token')

# Retrieve secrets
DB_HOST=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${VAULT_URL}/secrets/db-host?api-version=7.4" | jq -r '.value')
DB_PASSWORD=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "${VAULT_URL}/secrets/db-password?api-version=7.4" | jq -r '.value')

export DB_HOST DB_PASSWORD
echo "Azure Key Vault secrets loaded for: ${VAULT_NAME}"
```

**Terraform for Key Vault setup**
```hcl
resource "azurerm_key_vault" "mulesoft" {
  name                = "mulesoft-${var.environment}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  purge_protection_enabled = true
  soft_delete_retention_days = 90

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.allowed_ips
  }
}

resource "azurerm_key_vault_access_policy" "mule_app" {
  key_vault_id = azurerm_key_vault.mulesoft.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.mule_app.principal_id

  secret_permissions = ["Get", "List"]
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.mulesoft.id

  expiration_date = timeadd(timestamp(), "8760h")  # 1 year
}
```

### How It Works
1. Azure Managed Identity eliminates the need to store Azure credentials in the Mule app
2. The IMDS endpoint (`169.254.169.254`) provides tokens without any stored secrets
3. Key Vault REST API returns secret values using the managed identity token
4. Network ACLs restrict Key Vault access to specific IPs or Azure services
5. Terraform provisions the vault, access policies, and initial secrets

### Gotchas
- Managed Identity only works on Azure VMs, AKS, or App Service — not on CloudHub
- For CloudHub deployments, use a Service Principal with client credentials instead
- Key Vault throttles at 4000 operations per 10 seconds per vault; cache secrets
- Soft-delete is enabled by default; deleted secrets are recoverable for 90 days
- Secret versions are immutable; updating creates a new version (old versions remain)

### Related
- [hashicorp-vault](../hashicorp-vault/) — HashiCorp Vault alternative
- [aws-secrets-manager](../aws-secrets-manager/) — AWS alternative
- [credential-rotation](../credential-rotation/) — Rotation patterns
