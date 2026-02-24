## HashiCorp Vault for MuleSoft
> Vault connector for startup secrets injection and runtime secret lookups

### When to Use
- Your organization uses HashiCorp Vault as the central secrets manager
- You need dynamic secrets (e.g., rotating database credentials) for Mule apps
- You want to eliminate stored credentials and use short-lived tokens instead

### Configuration

**pom.xml — Vault connector**
```xml
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-hashicorp-vault-connector</artifactId>
    <version>1.2.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

**src/main/mule/global.xml — Vault configuration**
```xml
<!-- Vault Properties Provider (resolves at startup) -->
<vault:config name="Vault_Config" doc:name="Vault Config">
    <vault:connection
        vaultUrl="${vault.url}"
        vaultToken="${vault.token}"
        engineVersion="V2" />
</vault:config>

<vault:config-properties
    config-ref="Vault_Config"
    path="secret/data/mulesoft/${env}"
    doc:name="Vault Properties" />

<!-- Use Vault secrets as regular properties -->
<db:config name="Database_Config">
    <db:generic-connection
        url="jdbc:postgresql://${db.host}:${db.port}/${db.name}"
        user="${db.user}"
        password="${db.password}" />
</db:config>
```

**Runtime secret lookup in a flow**
```xml
<flow name="get-api-key-flow">
    <vault:read-secret
        config-ref="Vault_Config"
        path="secret/data/api-keys/payment-gateway"
        doc:name="Read API Key">
    </vault:read-secret>
    <set-variable variableName="apiKey"
        value="#[payload.data.api_key]"
        doc:name="Extract Key" />
</flow>
```

**Vault policy (vault-policy.hcl)**
```hcl
# Policy for Mule applications
path "secret/data/mulesoft/*" {
  capabilities = ["read", "list"]
}

path "secret/metadata/mulesoft/*" {
  capabilities = ["read", "list"]
}

path "database/creds/mule-app-role" {
  capabilities = ["read"]
}
```

**Vault setup commands**
```bash
# Enable KV v2 secrets engine
vault secrets enable -path=secret kv-v2

# Store Mule app secrets
vault kv put secret/mulesoft/prod \
    db.host=prod-db.internal \
    db.port=5432 \
    db.user=mule_app \
    db.password=S3cur3P@ssw0rd \
    api.client_secret=abc123def456

# Create app policy
vault policy write mule-app vault-policy.hcl

# Create AppRole for Mule (preferred over tokens)
vault auth enable approle
vault write auth/approle/role/mule-app \
    secret_id_ttl=24h \
    token_ttl=1h \
    token_max_ttl=4h \
    policies=mule-app

# Get role-id and secret-id
vault read auth/approle/role/mule-app/role-id
vault write -f auth/approle/role/mule-app/secret-id
```

### How It Works
1. `vault:config-properties` loads all secrets from a Vault KV path at startup and exposes them as Mule properties
2. Secrets are referenced with standard `${property}` syntax — the app does not know they come from Vault
3. Runtime lookups via `vault:read-secret` fetch secrets on-demand (useful for short-lived tokens)
4. AppRole authentication is preferred over static tokens for production use
5. Dynamic database credentials can be generated via Vault's database secrets engine

### Gotchas
- Vault tokens expire; use AppRole with auto-renewal or a short-lived token refreshed at deploy time
- KV v2 paths require `secret/data/` prefix in the API (not just `secret/`)
- If Vault is unreachable at startup, the Mule app fails to deploy — ensure network connectivity
- Vault audit logs should be enabled to track which secrets are accessed
- The Vault connector caches secrets at startup; changes in Vault require app restart (unless using runtime lookups)

### Related
- [aws-secrets-manager](../aws-secrets-manager/) — AWS-native alternative
- [azure-key-vault](../azure-key-vault/) — Azure alternative
- [credential-rotation](../credential-rotation/) — Automated rotation patterns
