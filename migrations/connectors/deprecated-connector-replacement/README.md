## Find and Replace Deprecated Connectors
> Identify and replace deprecated Mule connectors with supported alternatives

### When to Use
- Runtime upgrade warnings about deprecated connectors
- Connector no longer receiving security patches
- MuleSoft announced connector end-of-life

### Configuration / Code

#### 1. Scan for Deprecated Connectors

```bash
# Check all POMs for connector versions
find /path/to/apps -name "pom.xml" -exec grep -l "mule-plugin" {} \;
```

#### 2. Common Replacement Mapping

| Deprecated | Replacement | Notes |
|---|---|---|
| Mule 3 HTTP Transport | HTTP Connector 1.9+ | Complete rewrite |
| Legacy SFTP | SFTP Connector 2.x | New operations |
| Old Email | Email Connector 1.8+ | Unified connector |
| Twitter Connector | HTTP + Twitter API v2 | Connector removed |
| Amazon S3 5.x | Amazon S3 6+ | AWS SDK v2 |
| LDAP 2.x | LDAP 3.x | Schema changes |

#### 3. Example: Old S3 to New S3

```xml
<!-- Old -->
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-amazon-s3-connector</artifactId>
    <version>5.7.0</version>
    <classifier>mule-plugin</classifier>
</dependency>

<!-- New -->
<dependency>
    <groupId>com.mulesoft.connectors</groupId>
    <artifactId>mule-amazon-s3-connector</artifactId>
    <version>6.2.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

### How It Works
1. MuleSoft deprecates connectors when underlying APIs change
2. Deprecated connectors stop receiving feature updates
3. End-of-life connectors receive no updates at all
4. Replacement connectors often have different operation names

### Migration Checklist
- [ ] Inventory all connectors and versions
- [ ] Check against MuleSoft deprecation notices
- [ ] Map deprecated to replacements
- [ ] Update POMs
- [ ] Refactor XML configurations
- [ ] Update DataWeave if payload structures changed
- [ ] Test all operations

### Gotchas
- GroupId may change between versions (org.mule vs com.mulesoft)
- New versions may have different defaults
- Error types may change, breaking error handling

### Related
- [connector-bulk-upgrade](../../runtime-upgrades/connector-bulk-upgrade/) - Bulk upgrade
