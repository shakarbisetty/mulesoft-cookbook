## Hardcoded Credentials to Secure Properties
> Remove hardcoded credentials and migrate to Mule Secure Properties

### When to Use
- Security audit found plaintext passwords in config files
- Credentials committed to version control
- Need per-environment secret management
- Preparing for production deployment

### Configuration / Code

#### 1. Identify Hardcoded Credentials

```bash
# Scan for common credential patterns
grep -rn "password\|secret\|apiKey\|token\|credential" \
    src/main/resources/*.properties src/main/resources/*.yaml \
    src/main/mule/*.xml | grep -v "secure::"
```

#### 2. Generate Encryption Key

```bash
openssl rand -base64 32
# Example output: k8sM3rP5nQ7xR2wT9yB4vF6hJ0lN1oA3cE5gI7kM9p=
```

#### 3. Encrypt Values

```bash
java -cp secure-properties-tool.jar \
    com.mulesoft.tools.SecurePropertiesTool \
    string encrypt AES CBC \
    "k8sM3rP5nQ7xR2wT9yB4vF6hJ0lN1oA3cE5gI7kM9p=" \
    "my-database-password"
# Output: ![encrypted-value-here]
```

#### 4. Create Secure Properties File

```properties
# src/main/resources/config-prod.secure.properties
db.password=![abcdef1234567890abcdef1234567890]
api.key=![fedcba0987654321fedcba0987654321]
sftp.password=![1234abcd5678efgh1234abcd5678efgh]
oauth.client.secret=![9876543210abcdef9876543210abcdef]
```

#### 5. Configure in Mule

```xml
<!-- Add secure properties module -->
<secure-properties:config name="Secure_Props"
    file="config-${env}.secure.properties"
    key="${secure.key}">
    <secure-properties:encrypt algorithm="AES" mode="CBC" />
</secure-properties:config>

<!-- Reference with secure:: prefix -->
<db:config name="DB_Config">
    <db:my-sql-connection
        host="${db.host}" port="3306"
        user="${db.user}"
        password="${secure::db.password}" />
</db:config>
```

#### 6. POM Dependency

```xml
<dependency>
    <groupId>com.mulesoft.modules</groupId>
    <artifactId>mule-secure-configuration-property-module</artifactId>
    <version>1.2.6</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 7. Pass Key at Runtime

```bash
# Local development
mvn clean package -Dsecure.key="${ENCRYPTION_KEY}"

# CloudHub deployment
anypoint-cli-v4 runtime-mgr app deploy \
    --property "secure.key:${ENCRYPTION_KEY}"
```

### How It Works
1. Secure Properties module decrypts values at runtime using an encryption key
2. The `${secure::}` prefix tells Mule to decrypt the value
3. The encryption key is passed as a JVM argument, never stored in code
4. AES/CBC encryption ensures values cannot be read without the key

### Migration Checklist
- [ ] Scan all config files for plaintext credentials
- [ ] Generate per-environment encryption keys
- [ ] Encrypt all sensitive values
- [ ] Create .secure.properties files
- [ ] Update Mule configs to use `${secure::}` prefix
- [ ] Store encryption keys in CI/CD secret manager
- [ ] Remove plaintext secrets from regular properties
- [ ] Add .secure.properties to version control (values are encrypted)
- [ ] Verify git history does not contain plaintext secrets

### Gotchas
- `${secure::}` prefix is required - without it you get the encrypted string
- Losing the encryption key means re-encrypting all values
- Do not commit encryption keys to version control
- Different environments should use different keys
- Module must be added as explicit dependency

### Related
- [properties-to-secure](../../cloudhub/properties-to-secure/) - CloudHub context
- [platform-permissions](../platform-permissions/) - Access control
