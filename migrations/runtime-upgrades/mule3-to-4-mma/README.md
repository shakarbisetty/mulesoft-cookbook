## Mule Migration Assistant (MMA) Usage Guide
> Use MuleSoft's Migration Assistant to convert Mule 3 applications to Mule 4 XML structure

### When to Use
- Migrating Mule 3.x applications to Mule 4.x
- Large Mule 3 portfolio requiring systematic migration
- Need automated conversion of flows, connectors, and MEL expressions to Mule 4 equivalents

### Configuration / Code

#### 1. Install MMA

```bash
# Download from MuleSoft (requires Anypoint Platform credentials)
# MMA is distributed as a standalone Java application

# Verify Java 8+ is available (MMA itself runs on Java 8)
java -version

# Extract MMA
unzip mule-migration-assistant-3.0.0.zip -d /opt/mma
chmod +x /opt/mma/bin/mma
```

#### 2. Run MMA on a Mule 3 Project

```bash
# Basic migration
/opt/mma/bin/mma \
    -projectBasePath /path/to/mule3-app \
    -destinationProjectBasePath /path/to/mule4-app \
    -muleVersion 4.6.0

# With report output
/opt/mma/bin/mma \
    -projectBasePath /path/to/mule3-app \
    -destinationProjectBasePath /path/to/mule4-app \
    -muleVersion 4.6.0 \
    -jsonReport /path/to/migration-report.json
```

#### 3. Key XML Transformations

**HTTP Listener (Mule 3 → Mule 4):**

```xml
<!-- Mule 3 -->
<http:inbound-endpoint host="0.0.0.0" port="8081" path="api" />

<!-- Mule 4 (MMA output) -->
<http:listener-config name="HTTP_Listener_config">
    <http:listener-connection host="0.0.0.0" port="8081" />
</http:listener-config>
<flow name="apiFlow">
    <http:listener config-ref="HTTP_Listener_config" path="/api" />
</flow>
```

**MEL to DataWeave:**

```xml
<!-- Mule 3 (MEL) -->
<set-payload value="#[flowVars.firstName + ' ' + flowVars.lastName]" />

<!-- Mule 4 (DataWeave) -->
<set-payload value="#[vars.firstName ++ ' ' ++ vars.lastName]" />
```

**Exception Strategy to Error Handling:**

```xml
<!-- Mule 3 -->
<catch-exception-strategy>
    <logger message="Error: #[exception.message]" level="ERROR" />
</catch-exception-strategy>

<!-- Mule 4 -->
<error-handler>
    <on-error-continue>
        <logger message="Error: #[error.description]" level="ERROR" />
    </on-error-continue>
</error-handler>
```

#### 4. Post-MMA Manual Fixes Checklist

```xml
<!-- MMA cannot auto-convert these — manual work required -->

<!-- 1. Custom Java components: rewrite MessageProcessor to use SDK -->
<!-- 2. MEL expressions with Java method calls: rewrite in DataWeave -->
<!-- 3. Mule 3 transports (JMS, VM, File): replace with Mule 4 connectors -->
<!-- 4. Global exception strategies: convert to error-handler blocks -->
<!-- 5. Poll scopes: replace with Scheduler source -->
```

### How It Works
1. MMA parses Mule 3 XML configuration files and applies transformation rules
2. It converts connector configurations, flow structures, and expression languages
3. MMA generates a migration report identifying what was auto-converted and what needs manual work
4. The output is a Mule 4 project skeleton that compiles but typically requires manual refinement

### Migration Checklist
- [ ] Run MMA and review the JSON migration report
- [ ] Fix all items flagged as "MANUAL" in the report
- [ ] Replace MEL expressions with DataWeave 2.0
- [ ] Update all connector configurations to Mule 4 versions
- [ ] Convert exception strategies to error handlers
- [ ] Replace `flowVars` with `vars`, `sessionVars` with Object Store
- [ ] Update POM to Mule 4 parent and dependencies
- [ ] Run MUnit tests (rewrite from Mule 3 MUnit format)
- [ ] Test end-to-end on Mule 4 runtime

### Gotchas
- MMA handles ~60-70% of migration automatically — significant manual work remains
- Custom Java `MessageProcessor` classes must be rewritten using the Mule SDK
- Session variables (`sessionVars`) have no Mule 4 equivalent — use Object Store or pass via headers
- Mule 3 `poll` scope becomes `scheduler` source in Mule 4
- MMA does not migrate MUnit tests — those must be rewritten manually
- Some connectors changed drastically (e.g., File, FTP) and MMA may generate incomplete configs

### What MMA Can't Convert — Manual Fix Guide

MMA covers ~60-70% of migration. The remaining 30-40% requires manual work. Here's exactly what MMA misses and how to fix each item:

#### Connector Replacement Matrix

| Mule 3 Connector/Transport | Mule 4 Replacement | MMA Converts? | Manual Work |
|---|---|---|---|
| HTTP Transport (inbound) | HTTP Listener | ✅ Partial | Verify listener config, TLS settings |
| HTTP Transport (outbound) | HTTP Requester | ✅ Partial | Verify auth config, connection pooling |
| VM Transport | VM Connector | ❌ No | Rewrite queue definitions, change to VM publish/consume |
| JMS Transport | JMS Connector | ❌ No | Rewrite with new connection factory config |
| File Transport | File Connector | ✅ Partial | Verify directory listeners, file matchers |
| FTP Transport | FTP Connector | ✅ Partial | Verify connection config, file matchers |
| SFTP Transport | SFTP Connector | ❌ No | Full rewrite with new key/password auth config |
| JDBC Transport | Database Connector | ❌ No | Rewrite all SQL operations, connection pooling |
| Salesforce Connector v8 | Salesforce Connector v10+ | ❌ No | Different operation names, config structure |
| SAP Connector | SAP Connector v5+ | ❌ No | Full config rewrite, new IDoc/BAPI operations |
| Custom Java (MessageProcessor) | Mule SDK Module | ❌ No | Full rewrite using `@Extension` annotations |
| DevKit Connector | Mule SDK Connector | ❌ No | Full rewrite using Mule SDK framework |

#### Expression Language Gaps

```xml
<!-- MMA converts simple MEL → DataWeave, but NOT these: -->

<!-- 1. MEL with Java method calls -->
<!-- Mule 3: -->
<set-payload value="#[new java.text.SimpleDateFormat('yyyy-MM-dd').format(new Date())]" />
<!-- Manual fix (DW): -->
<set-payload value="#[now() as String {format: 'yyyy-MM-dd'}]" />

<!-- 2. MEL with server.dateTime -->
<!-- Mule 3: -->
<set-variable variableName="timestamp" value="#[server.dateTime.format('yyyyMMddHHmmss')]" />
<!-- Manual fix (DW): -->
<set-variable variableName="timestamp" value="#[now() as String {format: 'yyyyMMddHHmmss'}]" />

<!-- 3. MEL with message.inboundProperties -->
<!-- Mule 3: -->
<logger message="#[message.inboundProperties['http.request.uri']]" />
<!-- Manual fix (DW): -->
<logger message="#[attributes.requestPath]" />

<!-- 4. MEL exception handling -->
<!-- Mule 3: -->
<logger message="#[exception.causedBy(java.net.ConnectException)]" />
<!-- Manual fix (DW): -->
<logger message="#[error.errorType.namespace == 'HTTP' and error.errorType.identifier == 'CONNECTIVITY']" />
```

#### Structural Changes MMA Misses

| Mule 3 Pattern | Mule 4 Equivalent | How to Migrate |
|---|---|---|
| `<catch-exception-strategy>` with `when` | `<on-error-continue type="...">` | Map `when` expressions to error types |
| `<choice-exception-strategy>` | `<error-handler>` with multiple handlers | Convert each choice to typed error handler |
| `<until-successful>` (sync) | `<until-successful>` (different config) | Update attributes (maxRetries, millisBetweenRetries → frequency) |
| `<scatter-gather>` (Mule 3) | `<scatter-gather>` (Mule 4) | Different result structure — `payload[0]`, `payload[1]` etc. |
| `<poll>` with watermark | `<scheduler>` + Object Store | Manual: extract watermark to OS, add scheduler trigger |
| Domain projects | Domain projects (different structure) | Manual: new domain project, shared configs, mule-domain-config.xml |
| `<flow-ref>` with `doc:name` | Same, but `target` attribute is new | Add `target` if you want to preserve original payload |

#### Migration Effort Estimation

| App Complexity | Flows | Connectors | MMA Coverage | Manual Effort |
|---|---|---|---|---|
| Simple (REST proxy) | 1-3 | HTTP only | ~90% | 2-4 hours |
| Medium (DB + transform) | 3-10 | HTTP, DB, File | ~70% | 1-3 days |
| Complex (multi-connector) | 10-30 | 5+ connectors | ~50% | 1-2 weeks |
| Enterprise (custom Java) | 30+ | Custom DevKit | ~30% | 3-6 weeks |

### Related
- [transport-to-connector](../transport-to-connector/) — Detailed transport migration
- [mule3-gateway-policies](../mule3-gateway-policies/) — API Gateway policy migration
- [mule3-domains-to-mule4](../../architecture/mule3-domains-to-mule4/) — Domain migration
