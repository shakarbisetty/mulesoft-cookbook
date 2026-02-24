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

### Related
- [transport-to-connector](../transport-to-connector/) — Detailed transport migration
- [mule3-gateway-policies](../mule3-gateway-policies/) — API Gateway policy migration
- [mule3-domains-to-mule4](../../architecture/mule3-domains-to-mule4/) — Domain migration
