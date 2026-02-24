## Plain Properties to Secure Properties
> Migrate plaintext configuration properties to encrypted Secure Properties for production security

### When to Use
- Application properties contain passwords, API keys, or tokens in plaintext
- Moving to CloudHub 2.0 which enforces secure property best practices
- Security audit requires encryption of sensitive configuration
- Need environment-specific secret management

### Configuration / Code

#### 1. Generate Encryption Key

```bash
# Generate a secure encryption key
openssl rand -base64 32
# Output: dGhpcyBpcyBhIHNlY3VyZSBlbmNyeXB0aW9uIGtleQ==
```

#### 2. Encrypt Property Values

```bash
# Using Mule Secure Properties Tool
java -cp secure-properties-tool.jar \
    com.mulesoft.tools.SecurePropertiesTool \
    string encrypt AES CBC \
    "dGhpcyBpcyBhIHNlY3VyZSBlbmNyeXB0aW9uIGtleQ==" \
    "my-secret-password"
# Output: ![abcdef1234567890]
```

#### 3. Before: Plaintext Properties

```properties
# src/main/resources/config-prod.properties
db.host=prod-db.example.com
db.port=3306
db.username=admin
db.password=my-secret-password
api.key=sk-1234567890abcdef
salesforce.client.secret=sf-secret-value
```

#### 4. After: Secure Properties

```properties
# src/main/resources/config-prod.properties
db.host=prod-db.example.com
db.port=3306
db.username=admin

# src/main/resources/config-prod.secure.properties
db.password=![abcdef1234567890abcdef1234567890]
api.key=![fedcba0987654321fedcba0987654321]
salesforce.client.secret=![1234abcd5678efgh1234abcd5678efgh]
```

#### 5. Mule Configuration

```xml
<!-- Secure Properties Configuration -->
<secure-properties:config name="Secure_Properties"
    file="config-${env}.secure.properties"
    key="${secure.key}">
    <secure-properties:encrypt algorithm="AES" mode="CBC" />
</secure-properties:config>

<!-- Regular Properties (non-sensitive) -->
<configuration-properties file="config-${env}.properties" />

<!-- Usage in flows -->
<http:request-config name="DB_Config">
    <http:request-connection
        host="${db.host}"
        port="${db.port}" />
</http:request-config>

<db:config name="Database_Config">
    <db:my-sql-connection
        host="${db.host}"
        port="${db.port}"
        user="${db.username}"
        password="${secure::db.password}" />
</db:config>
```

#### 6. Pass Encryption Key at Deploy Time

```bash
# CloudHub 2.0 deployment
anypoint-cli-v4 runtime-mgr app deploy \
    --name "my-api" \
    --target "Production-PS" \
    --property "secure.key:${ENCRYPTION_KEY}" \
    --environment "Production"

# Maven deployment
mvn deploy -DmuleDeploy \
    -Dsecure.key="${ENCRYPTION_KEY}" \
    -Denv=prod
```

#### 7. POM Dependency

```xml
<dependency>
    <groupId>com.mulesoft.modules</groupId>
    <artifactId>mule-secure-configuration-property-module</artifactId>
    <version>1.2.6</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

### How It Works
1. The Secure Properties module decrypts property values at runtime using a key passed as a JVM argument
2. Properties prefixed with `${secure::}` are resolved from the encrypted properties file
3. The encryption key is never stored in the codebase — it is injected at deployment time
4. AES/CBC encryption ensures values cannot be read from the properties file without the key

### Migration Checklist
- [ ] Identify all sensitive properties across all environments
- [ ] Generate encryption keys (one per environment)
- [ ] Encrypt all sensitive values using the Secure Properties Tool
- [ ] Create `.secure.properties` files for each environment
- [ ] Update Mule config to reference `${secure::property.name}` for sensitive values
- [ ] Store encryption keys in CI/CD secret manager (not in code)
- [ ] Remove plaintext secrets from regular properties files
- [ ] Test decryption works in each environment
- [ ] Add `.secure.properties` to version control (values are encrypted)

### Gotchas
- The `${secure::}` prefix is required when referencing encrypted properties — without it, you get the raw encrypted string
- Encryption keys must be managed carefully — losing the key means re-encrypting all values
- Do not commit the encryption key to version control
- Different environments should use different encryption keys
- Secure Properties module must be added as a dependency — it is not built into the runtime

### Related
- [ch1-app-to-ch2](../ch1-app-to-ch2/) — CloudHub 2.0 migration
- [credentials-to-secure-props](../../security/credentials-to-secure-props/) — Hardcoded credentials cleanup
- [cicd-for-ch2](../../build-tools/cicd-for-ch2/) — CI/CD secret management
