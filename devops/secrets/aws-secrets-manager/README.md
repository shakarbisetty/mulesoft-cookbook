## AWS Secrets Manager for MuleSoft
> Retrieve secrets from AWS Secrets Manager at startup and runtime

### When to Use
- Your MuleSoft apps run on CloudHub 2.0 or RTF with AWS backend
- You standardize on AWS for secrets management
- You need automatic secret rotation with Lambda functions

### Configuration

**Custom properties provider using Mule SDK (DataWeave approach)**
```xml
<!-- Option 1: Use AWS SDK via custom Java module -->
<dependency>
    <groupId>com.example</groupId>
    <artifactId>mule-aws-secrets-provider</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

**DataWeave script for runtime secret retrieval**
```dataweave
%dw 2.0
import * from dw::core::Binaries
output application/json
---
// Use HTTP Requester to call AWS Secrets Manager API
// The IAM role attached to the runtime provides authentication
{
    secretId: "mulesoft/prod/db-credentials",
    versionStage: "AWSCURRENT"
}
```

**src/main/mule/aws-secrets-flow.xml — HTTP-based retrieval**
```xml
<flow name="retrieve-aws-secret-flow">
    <!-- AWS SDK-based secret retrieval -->
    <http:request method="POST"
        config-ref="AWS_SecretsManager_Config"
        path="/"
        doc:name="Get Secret">
        <http:headers>
            #[{
                "X-Amz-Target": "secretsmanager.GetSecretValue",
                "Content-Type": "application/x-amz-json-1.1"
            }]
        </http:headers>
        <http:body>
            #[output application/json --- {
                "SecretId": "mulesoft/prod/db-credentials"
            }]
        </http:body>
    </http:request>

    <set-variable variableName="dbCredentials"
        value="#[output application/java --- read(payload.SecretString, 'application/json')]"
        doc:name="Parse Secret" />
</flow>
```

**Startup script for CloudHub 2.0 (inject secrets as properties)**
```bash
#!/usr/bin/env bash
set -euo pipefail

# Retrieve secrets before Mule starts
SECRET_JSON=$(aws secretsmanager get-secret-value \
    --secret-id "mulesoft/${ENV}/app-secrets" \
    --query 'SecretString' \
    --output text \
    --region us-east-2)

# Export as system properties
export DB_HOST=$(echo "$SECRET_JSON" | jq -r '.db_host')
export DB_PASSWORD=$(echo "$SECRET_JSON" | jq -r '.db_password')
export API_KEY=$(echo "$SECRET_JSON" | jq -r '.api_key')

echo "Secrets loaded for environment: ${ENV}"
```

**Terraform for secret + rotation**
```hcl
resource "aws_secretsmanager_secret" "mule_db_creds" {
  name        = "mulesoft/prod/db-credentials"
  description = "Database credentials for Mule production apps"

  tags = {
    Application = "mulesoft"
    Environment = "prod"
  }
}

resource "aws_secretsmanager_secret_version" "mule_db_creds_value" {
  secret_id = aws_secretsmanager_secret.mule_db_creds.id
  secret_string = jsonencode({
    db_host     = "prod-db.internal"
    db_port     = "5432"
    db_user     = "mule_app"
    db_password = var.db_password
  })
}

resource "aws_secretsmanager_secret_rotation" "mule_db_rotation" {
  secret_id           = aws_secretsmanager_secret.mule_db_creds.id
  rotation_lambda_arn = aws_lambda_function.secret_rotation.arn

  rotation_rules {
    automatically_after_days = 30
  }
}
```

### How It Works
1. Secrets are stored in AWS Secrets Manager with a naming convention: `mulesoft/{env}/{secret-name}`
2. At deploy time, a startup script retrieves secrets and injects them as environment variables
3. For runtime lookups, a Mule flow calls the Secrets Manager API using IAM role-based auth
4. Automatic rotation via Lambda ensures credentials are refreshed without manual intervention
5. Terraform manages secret lifecycle and rotation configuration as code

### Gotchas
- IAM role must have `secretsmanager:GetSecretValue` permission on the specific secret ARN
- CloudHub 2.0 supports instance profiles; on-prem or RTF needs explicit AWS credentials
- Secret rotation requires a Lambda function that knows how to update the target system (e.g., RDS)
- Secrets Manager charges per secret per month + per API call; cache aggressively
- The `AWSPREVIOUS` version stage lets you roll back if rotation fails

### Related
- [hashicorp-vault](../hashicorp-vault/) — HashiCorp Vault alternative
- [azure-key-vault](../azure-key-vault/) — Azure alternative
- [credential-rotation](../credential-rotation/) — Rotation patterns
