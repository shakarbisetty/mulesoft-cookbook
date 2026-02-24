## Secure Properties Module
> Encrypt sensitive configuration values with the MuleSoft Secure Properties module

### When to Use
- You need to store encrypted passwords, API keys, or tokens in config files
- Compliance requires that secrets are never stored in plaintext in source control
- You want a self-contained encryption solution without external vaults

### Configuration

**pom.xml — add the Secure Properties module**
```xml
<dependency>
    <groupId>com.mulesoft.modules</groupId>
    <artifactId>mule-secure-configuration-property-module</artifactId>
    <version>1.2.7</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

**Encrypt a value using the Secure Properties tool**
```bash
# Download the tool from MuleSoft docs or use the Maven plugin
java -cp secure-properties-tool.jar \
    com.mulesoft.tools.SecurePropertiesTool \
    string encrypt AES CBC \
    --key "MyEncryptionKey1" \
    --value "SuperSecretPassword123"

# Output: ![abcdef1234567890abcdef1234567890]
```

**src/main/resources/config/config-prod-secure.yaml**
```yaml
db:
  user: "app_user"
  password: "![abcdef1234567890abcdef1234567890]"

api:
  clientSecret: "![1234567890abcdef1234567890abcdef]"

smtp:
  password: "![fedcba0987654321fedcba0987654321]"
```

**src/main/mule/global.xml**
```xml
<!-- Load secure properties BEFORE regular properties -->
<secure-properties:config
    name="Secure_Properties"
    file="config/config-${env}-secure.yaml"
    key="${secure.key}"
    doc:name="Secure Properties Config">
    <secure-properties:encrypt
        algorithm="AES"
        mode="CBC" />
</secure-properties:config>

<configuration-properties
    file="config/config-${env}.yaml"
    doc:name="Environment Config" />
```

**Deploy with the decryption key**
```bash
mvn mule:deploy -B \
    -Denv=prod \
    -Dsecure.key=MyEncryptionKey1
```

**Runtime Manager setup**
```
Application Properties:
  secure.key = MyEncryptionKey1   (mark as "Secure" in RM UI)
  env = prod
```

### How It Works
1. The Secure Properties module decrypts values wrapped in `![]` at startup using the provided key
2. The decryption key itself is passed as a system property or Runtime Manager secure property
3. Encrypted values can be used anywhere regular properties are used: `${db.password}`
4. AES/CBC is the recommended algorithm; the key must be exactly 16 characters for AES-128
5. The module loads before regular `configuration-properties`, so secure values are available to all configs

### Gotchas
- The encryption key must be exactly 16 (AES-128), 24 (AES-192), or 32 (AES-256) characters
- Never commit the encryption key to source control — inject it via CI/CD secrets or Runtime Manager
- If the key is wrong, the app fails at startup with a decryption error (no partial starts)
- Each environment can use a different encryption key for additional isolation
- The `secure-properties-tool.jar` is a separate download; it is not bundled with Studio
- Always use `CBC` mode (not `ECB`) to avoid pattern-leaking vulnerabilities

### Related
- [property-externalization](../property-externalization/) — Non-sensitive external config
- [hashicorp-vault](../../secrets/hashicorp-vault/) — External vault for secrets
- [aws-secrets-manager](../../secrets/aws-secrets-manager/) — AWS-native secrets
