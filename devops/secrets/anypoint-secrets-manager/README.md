## Anypoint Secrets Manager
> Store TLS contexts, keystores, and truststores in Anypoint platform-native secrets

### When to Use
- You want MuleSoft-native secret management without external vaults
- You need to manage TLS certificates and keystores for API gateways
- You want secrets scoped to Anypoint environments and business groups

### Configuration

**CLI commands for secret management**
```bash
# Create a shared secret
anypoint-cli-v4 secrets-mgr:shared-secret:create \
    --name "payment-api-key" \
    --type "symmetric-key" \
    --key "$(cat payment-api.key)" \
    --organization "MyOrg" \
    --environment "PROD"

# Create a TLS context
anypoint-cli-v4 secrets-mgr:tls-context:create \
    --name "api-gateway-tls" \
    --keystore "keystore.jks" \
    --keystore-password "$(vault read -field=password secret/keystore)" \
    --truststore "truststore.jks" \
    --truststore-password "$(vault read -field=password secret/truststore)" \
    --organization "MyOrg" \
    --environment "PROD"

# List secrets
anypoint-cli-v4 secrets-mgr:shared-secret:list \
    --organization "MyOrg" \
    --environment "PROD"
```

**Using secrets in API Manager policies**
```json
{
    "policyTemplateId": "jwt-validation",
    "configuration": {
        "jwtKeyOrigin": "jwks",
        "jwksUrl": "https://auth.example.com/.well-known/jwks.json",
        "signingMethod": "rsa",
        "signingKeyLength": 256,
        "tlsContext": "api-gateway-tls"
    }
}
```

**Using TLS context in Mule app (CloudHub 2.0)**
```xml
<tls:context name="HTTPS_TLS_Context" doc:name="TLS Context">
    <tls:key-store
        type="jks"
        path="${keystore.path}"
        keyPassword="${keystore.key.password}"
        password="${keystore.password}" />
    <tls:trust-store
        type="jks"
        path="${truststore.path}"
        password="${truststore.password}" />
</tls:context>

<http:listener-config name="HTTPS_Listener">
    <http:listener-connection
        host="0.0.0.0"
        port="${https.port}"
        tlsContext="HTTPS_TLS_Context"
        protocol="HTTPS" />
</http:listener-config>
```

**Automation script for certificate renewal**
```bash
#!/usr/bin/env bash
set -euo pipefail

ORG="MyOrg"
ENV="PROD"
CERT_NAME="api-gateway-tls"

# Check certificate expiry
EXPIRY=$(anypoint-cli-v4 secrets-mgr:tls-context:describe \
    --name "$CERT_NAME" \
    --organization "$ORG" \
    --environment "$ENV" \
    --output json | jq -r '.expirationDate')

EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
NOW_EPOCH=$(date +%s)
DAYS_LEFT=$(( (EXPIRY_EPOCH - NOW_EPOCH) / 86400 ))

if [ "$DAYS_LEFT" -lt 30 ]; then
    echo "Certificate expires in $DAYS_LEFT days. Renewing..."

    # Generate new certificate (using certbot, ACME, or internal CA)
    # ... certificate generation steps ...

    # Update TLS context
    anypoint-cli-v4 secrets-mgr:tls-context:update \
        --name "$CERT_NAME" \
        --keystore "new-keystore.jks" \
        --keystore-password "$NEW_KEYSTORE_PASSWORD" \
        --organization "$ORG" \
        --environment "$ENV"

    echo "Certificate renewed successfully."
else
    echo "Certificate valid for $DAYS_LEFT more days."
fi
```

### How It Works
1. Anypoint Secrets Manager stores secrets at the environment level within a business group
2. TLS contexts bundle keystore + truststore and can be referenced by API policies and Flex Gateway
3. Shared secrets store symmetric keys, API keys, or tokens
4. Secrets are encrypted at rest and only accessible by authorized apps in the same environment
5. CLI commands enable automation of secret lifecycle in CI/CD pipelines

### Gotchas
- Secrets Manager is environment-scoped; you must create secrets separately for each environment
- TLS contexts created in Secrets Manager are available to API Manager and Flex Gateway, not directly in Mule flows
- For Mule flow-level TLS, use Secure Properties to inject keystore passwords
- There is no built-in automatic rotation; you must script it (see renewal script above)
- Secrets Manager has a limit on the number of secrets per environment; check your license

### Related
- [hashicorp-vault](../hashicorp-vault/) — External vault with more features
- [secure-properties](../../environments/secure-properties/) — Encrypted properties in code
- [credential-rotation](../credential-rotation/) — Rotation patterns
