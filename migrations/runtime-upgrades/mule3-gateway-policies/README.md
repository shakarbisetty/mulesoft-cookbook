## Migrate Mule 3 API Gateway Policies
> Convert Mule 3 API Gateway custom and OOTB policies to Mule 4 API Gateway format

### When to Use
- Migrating from Mule 3 API Gateway to Mule 4 embedded API Gateway
- Custom policies written in Mule 3 XML need conversion
- Moving from on-prem API Gateway to Flex Gateway
- OOTB policies need reconfiguration for Mule 4

### Configuration / Code

#### 1. Mule 3 Policy Structure → Mule 4

```
# Mule 3 policy structure
my-policy/
├── my-policy.xml          # Policy flow
├── my-policy.yaml         # Policy definition
└── mule-artifact.json     # (not present in Mule 3)

# Mule 4 policy structure
my-policy/
├── src/main/mule/template.xml    # Policy template
├── my-policy.yaml                 # Policy definition
├── pom.xml                        # Maven build
└── mule-artifact.json             # Artifact descriptor
```

#### 2. Convert Policy Definition YAML

```yaml
# Mule 3 policy definition
id: custom-rate-limit
name: Custom Rate Limit
description: Limits request rate per client
category: Security
type: custom
resourceLevelSupported: true
configuration:
  - propertyName: maxRequests
    type: int
    defaultValue: 100

# Mule 4 policy definition
id: custom-rate-limit
name: Custom Rate Limit
description: Limits request rate per client
category: Security
type: custom
resourceLevelSupported: true
supportedPoliciesVersions: ">=1.0.0"
violationCategory: qos
configuration:
  - propertyName: maxRequests
    name: Maximum Requests
    type: int
    defaultValue: 100
    description: Max requests per time window
```

#### 3. Convert Policy XML

```xml
<!-- Mule 3 Policy XML -->
<policy xmlns="http://www.mulesoft.org/schema/mule/policy"
        policyName="Custom Rate Limit">
    <before>
        <set-variable variableName="clientId"
            value="#[message.inboundProperties['client_id']]" />
        <custom-processor class="com.mycompany.RateLimiter" />
    </before>
    <after>
        <set-property propertyName="X-RateLimit-Remaining"
            value="#[flowVars['remaining']]" />
    </after>
</policy>

<!-- Mule 4 Policy XML (template.xml) -->
<http-policy:proxy name="Custom Rate Limit"
    xmlns:http-policy="http://www.mulesoft.org/schema/mule/http-policy">
    <http-policy:source>
        <http-policy:execute-next />
        <set-variable variableName="clientId"
            value="#[attributes.headers.'client_id']" />
        <!-- Use DataWeave or Java module instead of custom processor -->
        <java:invoke-static
            class="com.mycompany.RateLimiter"
            method="check(String, int)"
            doc:name="Rate limit check">
            <java:args>#[{
                clientId: vars.clientId,
                maxRequests: {{maxRequests}}
            }]</java:args>
        </java:invoke-static>
    </http-policy:source>
</http-policy:proxy>
```

#### 4. POM for Mule 4 Custom Policy

```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.mycompany</groupId>
    <artifactId>custom-rate-limit-policy</artifactId>
    <version>1.0.0</version>
    <packaging>mule-policy</packaging>

    <parent>
        <groupId>org.mule.tools.maven</groupId>
        <artifactId>mule-plugin-parent</artifactId>
        <version>4.6.0</version>
    </parent>

    <properties>
        <mule.version>4.6.0</mule.version>
    </properties>

    <build>
        <plugins>
            <plugin>
                <groupId>org.mule.tools.maven</groupId>
                <artifactId>mule-maven-plugin</artifactId>
                <extensions>true</extensions>
            </plugin>
        </plugins>
    </build>
</project>
```

#### 5. OOTB Policy Mapping

| Mule 3 Policy | Mule 4 Equivalent | Notes |
|---|---|---|
| Client ID Enforcement | Client ID Enforcement | Config format changed |
| Rate Limiting | Rate Limiting - SLA Based | New sliding window option |
| HTTP Basic Auth | HTTP Basic Auth | Same concept, new XML |
| IP Whitelist | IP Allowlist | Renamed + new syntax |
| IP Blacklist | IP Blocklist | Renamed + new syntax |
| OAuth 2.0 Token Validation | OAuth 2.0 Token Validation | New token introspection options |
| Header Injection | Header Injection/Removal | Split into separate policies |
| CORS | CORS | Enhanced configuration |

### How It Works
1. Mule 3 policies use `<before>` and `<after>` blocks around the API flow
2. Mule 4 policies use `<http-policy:proxy>` with `<http-policy:execute-next />` marking where the actual API executes
3. Custom processors are replaced with Java module invocations or DataWeave transformations
4. Policy projects are Maven-based in Mule 4 and published to Exchange

### Migration Checklist
- [ ] Inventory all applied policies per API
- [ ] Map OOTB Mule 3 policies to Mule 4 equivalents
- [ ] Convert custom policy XML to Mule 4 template format
- [ ] Update policy definition YAML
- [ ] Create Maven project for each custom policy
- [ ] Publish policies to Exchange
- [ ] Apply policies via API Manager
- [ ] Test policy enforcement end-to-end

### Gotchas
- Mule 3 `message.inboundProperties` does not exist in Mule 4 — use `attributes.headers` or `attributes.queryParams`
- Custom Java-based policies must use the Mule 4 SDK, not MessageProcessor
- Policy ordering may differ between Mule 3 and 4 — verify execution order
- Some Mule 3 policies have no direct Mule 4 equivalent and require custom development
- Flex Gateway policies use a different format (YAML-based) than Mule 4 embedded gateway

### Related
- [mule3-to-4-mma](../mule3-to-4-mma/) — Overall Mule 3 to 4 migration
- [api-gw-to-flex-gw](../../security/api-gw-to-flex-gw/) — Flex Gateway migration
- [platform-permissions](../../security/platform-permissions/) — Access control migration
