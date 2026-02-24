## Publish Custom Policy to Exchange
> Package and publish a custom policy to Anypoint Exchange for org-wide reuse.

### When to Use
- Sharing custom policies across teams and environments
- Versioning policies for governance and rollback
- Making policies available in API Manager UI

### Configuration / Code

**Policy definition (policy-definition.yaml):**
```yaml
id: custom-header-policy
name: Custom Header Policy
description: Adds custom headers to requests
category: Security
type: custom
resourceLevelSupported: true
configuration:
- propertyName: headerName
  name: Header Name
  type: string
  required: true
- propertyName: headerValue
  name: Header Value
  type: string
  required: true
```

**Publish to Exchange:**
```bash
anypoint-cli-v4 exchange asset upload \
  --organization $ORG_ID \
  --name "Custom Header Policy" \
  --type policy \
  --mainFile policy.wasm \
  --files policy-definition.yaml \
  --version 1.0.0
```

### How It Works
1. Define policy metadata in `policy-definition.yaml`
2. Build the policy (WASM binary or DataWeave script)
3. Upload to Exchange using the Anypoint CLI
4. Policy appears in API Manager for application to any API

### Gotchas
- Exchange asset names must be unique within the organization
- Version numbers follow semver — cannot overwrite published versions
- Policy definition schema must match the configuration your code expects
- Test policies locally before publishing — rollback requires publishing a new version

### Related
- [Rust WASM Policy](../rust-wasm-policy/) — building custom policies
- [API Governance](../../governance/conformance-profile/) — governance rules
