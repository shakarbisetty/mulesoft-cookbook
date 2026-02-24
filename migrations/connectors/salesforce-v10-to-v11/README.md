## Salesforce Connector v10 to v11 Breaking Changes
> Migrate from Salesforce Connector v10 to v11 with breaking API changes

### When to Use
- Upgrading to Mule 4.9+ which requires Salesforce Connector v11
- Need Salesforce API v59+ features
- Current v10 connector has deprecation warnings

### Configuration / Code

#### 1. POM Dependency Update

```xml
<!-- Before: v10 -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-salesforce-connector</artifactId>
    <version>10.20.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<!-- After: v11 -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-salesforce-connector</artifactId>
    <version>11.2.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 2. Connection Configuration Changes

```xml
<!-- v11: may have renamed/new attributes -->
<salesforce:sfdc-config name="Salesforce_Config">
    <salesforce:basic-connection
        username="${sf.username}"
        password="${secure::sf.password}"
        securityToken="${secure::sf.token}" />
</salesforce:sfdc-config>
```

#### 3. Query Parameter Syntax

```xml
<!-- v10 -->
<salesforce:query config-ref="Salesforce_Config">
    <salesforce:salesforce-query>
        SELECT Id, Name FROM Account WHERE Name = ':name'
    </salesforce:salesforce-query>
    <salesforce:parameters>
        <salesforce:parameter key="name" value="#[vars.accountName]" />
    </salesforce:parameters>
</salesforce:query>

<!-- v11: DW expression for parameters -->
<salesforce:query config-ref="Salesforce_Config">
    <salesforce:salesforce-query>
        SELECT Id, Name FROM Account WHERE Name = ':name'
    </salesforce:salesforce-query>
    <salesforce:parameters>#[{
        'name': vars.accountName
    }]</salesforce:parameters>
</salesforce:query>
```

#### 4. Bulk API v2 Default

```xml
<!-- v11 defaults to Bulk API v2 -->
<salesforce:bulk-create-job config-ref="Salesforce_Config"
    objectType="Account"
    operation="insert">
    <salesforce:objects>#[payload]</salesforce:objects>
</salesforce:bulk-create-job>
```

### How It Works
1. v11 aligns with Salesforce API v59+ changes
2. Bulk API operations default to v2 (more efficient for large datasets)
3. Some operations renamed or restructured for consistency
4. OAuth flows updated for latest security requirements

### Migration Checklist
- [ ] Update connector version in POM
- [ ] Review connection configurations
- [ ] Update query parameter syntax
- [ ] Migrate Bulk API operations to v2 syntax
- [ ] Test all CRUD operations
- [ ] Verify OAuth flows
- [ ] Update error handling for new error types

### Gotchas
- Bulk API v2 has different batch size limits
- Some deprecated operations removed in v11
- Platform Events/CDC may have payload changes
- Test in sandbox before production

### Related
- [connector-bulk-upgrade](../connector-bulk-upgrade/) - Bulk upgrade strategy
- [mule46-to-49](../../runtime-upgrades/mule46-to-49/) - Runtime upgrade
