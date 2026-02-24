## Feature Flags
> Toggle API behavior with system properties and runtime configuration

### When to Use
- You want to deploy code to production without activating new features
- You need to A/B test or canary release specific functionality
- You want operations teams to toggle features without redeployment

### Configuration

**src/main/resources/config/config-common.yaml**
```yaml
feature:
  async-processing: "false"
  new-validation-engine: "false"
  batch-v2: "false"
  enhanced-logging: "false"
  rate-limiting: "true"
```

**src/main/mule/feature-router.xml**
```xml
<sub-flow name="feature-check-flow">
    <set-variable variableName="asyncEnabled"
        value="${feature.async-processing}" doc:name="Check Async Flag" />
    <set-variable variableName="newValidation"
        value="${feature.new-validation-engine}" doc:name="Check Validation Flag" />
</sub-flow>

<!-- Feature-gated flow -->
<flow name="process-order-flow">
    <flow-ref name="feature-check-flow" />

    <choice doc:name="Feature: Async Processing">
        <when expression="#[vars.asyncEnabled == 'true']">
            <flow-ref name="async-order-processor" />
        </when>
        <otherwise>
            <flow-ref name="sync-order-processor" />
        </otherwise>
    </choice>

    <choice doc:name="Feature: Validation Engine">
        <when expression="#[vars.newValidation == 'true']">
            <flow-ref name="validation-v2-flow" />
        </when>
        <otherwise>
            <flow-ref name="validation-v1-flow" />
        </otherwise>
    </choice>
</flow>
```

**Object Store-based dynamic flags (no restart required)**
```xml
<os:object-store name="featureFlagStore"
    persistent="true"
    entryTtl="5"
    entryTtlUnit="MINUTES"
    doc:name="Feature Flag Store" />

<flow name="check-dynamic-flag-flow">
    <os:retrieve key="#['feature.' ++ vars.flagName]"
        objectStore="featureFlagStore"
        target="flagValue"
        doc:name="Get Flag">
        <os:default-value>false</os:default-value>
    </os:retrieve>
</flow>

<flow name="set-flag-flow">
    <http:listener path="/admin/flags/{flagName}" method="PUT"
        config-ref="HTTP_Admin_Listener" />
    <os:store key="#['feature.' ++ attributes.uriParams.flagName]"
        objectStore="featureFlagStore"
        doc:name="Set Flag">
        <os:value>#[payload.enabled]</os:value>
    </os:store>
    <set-payload value='#[{"flag": attributes.uriParams.flagName, "enabled": payload.enabled}]' />
</flow>
```

**MUnit tests for both flag states**
```xml
<munit:test name="async-enabled-test" description="Process order with async enabled">
    <munit:behavior>
        <munit-tools:mock-when processor="mule:set-variable">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="variableName"
                    whereValue="asyncEnabled" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:variables>
                    <munit-tools:variable key="asyncEnabled" value="true" />
                </munit-tools:variables>
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>
    <munit:execution>
        <flow-ref name="process-order-flow" />
    </munit:execution>
    <munit:validation>
        <munit-tools:verify-call processor="flow-ref">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="name"
                    whereValue="async-order-processor" />
            </munit-tools:with-attributes>
        </munit-tools:verify-call>
    </munit:validation>
</munit:test>
```

### How It Works
1. **Static flags** use system properties loaded from YAML; toggled by changing Runtime Manager properties (requires restart)
2. **Dynamic flags** use Object Store; toggled via admin API (no restart, but adds latency)
3. **Choice routers** branch on flag values, directing traffic to old or new code paths
4. **MUnit tests** must cover both flag states to prevent regressions
5. Flags can be environment-specific: enabled in DEV/QA, disabled in PROD until ready

### Gotchas
- Remove feature flags once a feature is fully released — flag debt accumulates quickly
- Static flags require app restart to take effect; use Object Store for instant toggles
- Object Store TTL controls cache duration vs. check frequency trade-off
- Admin API for flags should be secured (IP allowlist or OAuth) to prevent unauthorized access
- Test both code paths in CI; do not assume the "off" path still works after months of changes

### Related
- [trunk-based-dev](../../cicd-pipelines/trunk-based-dev/) — Feature flags enable trunk-based workflow
- [canary-release](../../deployment/canary-release/) — Gradual rollout with flags
- [env-specific-config](../env-specific-config/) — Environment configuration patterns
