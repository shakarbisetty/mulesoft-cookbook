## Trunk-Based Development for MuleSoft
> Short-lived feature branches with feature flags, MUnit gates, and fast-forward merges

### When to Use
- You want to eliminate long-lived branches and merge conflicts
- Your team practices continuous integration with multiple merges per day
- You need feature flags to decouple deployment from release

### Configuration

**Branch strategy rules (enforce via repository settings)**
```
main (protected)
  ├── feat/MULE-123-order-api    (max 2-day lifetime)
  ├── feat/MULE-456-batch-job    (max 2-day lifetime)
  └── hotfix/MULE-789-fix-auth   (max 4-hour lifetime)
```

**Feature flag system property in mule-artifact.json**
```json
{
  "minMuleVersion": "4.6.0",
  "secureProperties": ["anypoint.platform.client_id", "anypoint.platform.client_secret"],
  "properties": {
    "feature.new-order-flow.enabled": "false",
    "feature.batch-v2.enabled": "false"
  }
}
```

**Feature flag in Mule flow (XML)**
```xml
<choice doc:name="Feature: New Order Flow">
    <when expression="#[p('feature.new-order-flow.enabled') == 'true']">
        <flow-ref name="new-order-flow" />
    </when>
    <otherwise>
        <flow-ref name="legacy-order-flow" />
    </otherwise>
</choice>
```

**MUnit gate for feature flag coverage**
```xml
<munit:test name="feature-flag-enabled-test" description="New order flow when flag is on">
    <munit:behavior>
        <munit-tools:mock-when processor="mule:set-variable">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="variableName" whereValue="featureEnabled"/>
            </munit-tools:with-attributes>
        </munit-tools:mock-when>
    </munit:behavior>
    <munit:execution>
        <flow-ref name="order-router-flow" />
    </munit:execution>
    <munit:validation>
        <munit-tools:assert-that expression="#[vars.routedTo]" is="#[MunitTools::equalTo('new')]" />
    </munit:validation>
</munit:test>
```

**CI gate script (runs on every PR)**
```bash
#!/usr/bin/env bash
set -euo pipefail

echo "=== Trunk-Based CI Gate ==="

# 1. Ensure branch is not stale (max 2 days from main)
DAYS_BEHIND=$(git log --oneline main..HEAD | wc -l)
if [ "$DAYS_BEHIND" -gt 20 ]; then
    echo "ERROR: Branch has $DAYS_BEHIND commits ahead of main. Rebase or split."
    exit 1
fi

# 2. Run MUnit tests
mvn test -B
if [ $? -ne 0 ]; then
    echo "ERROR: MUnit tests failed. Fix before merging."
    exit 1
fi

# 3. Check MUnit coverage threshold
COVERAGE=$(grep -oP 'coverage="(\d+)"' target/site/munit/coverage/summary.html | head -1 | grep -oP '\d+')
if [ "${COVERAGE:-0}" -lt 80 ]; then
    echo "ERROR: MUnit coverage ${COVERAGE}% is below 80% threshold."
    exit 1
fi

echo "All gates passed. Ready to merge."
```

### How It Works
1. **Short-lived branches** (2 days max) reduce merge conflicts and integration risk
2. **Feature flags** via Mule system properties let you deploy code without activating it
3. **MUnit gates** enforce that both the old and new code paths have test coverage
4. **CI runs on every push** to the feature branch; merge is blocked until all gates pass
5. **Fast-forward merges** keep a linear history on `main`
6. Feature flags are toggled per environment via property overrides in Runtime Manager

### Gotchas
- Feature flags add complexity; remove them once the feature is fully released (flag debt)
- The `p()` function reads system properties at startup; changes require a restart unless you use Object Store
- Protect `main` with branch rules: require CI pass, no force push, require linear history
- Short-lived branches work best when stories are small (1-2 day scope)
- Test both flag-on and flag-off paths to prevent regressions when toggling

### Related
- [feature-flags](../../environments/feature-flags/) — Detailed feature flag patterns
- [blue-green](../../deployment/blue-green/) — Blue-green deploys for flag rollout
- [gitlab-ci](../gitlab-ci/) — CI pipeline to enforce these gates
