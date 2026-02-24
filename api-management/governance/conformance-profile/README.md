## API Conformance Profile
> Define organization-wide API design standards and automatically validate specs against them.

### When to Use
- Enforcing consistent API design across teams
- Automated API spec review in CI/CD pipelines
- Governance compliance for regulated industries

### Configuration / Code

**Conformance profile (Exchange):**
```yaml
profile:
  name: "Enterprise API Standards v2"
  rules:
    - id: api-versioning
      description: "API base path must include version"
      pattern: "/api/v[0-9]+/"
      severity: error
    - id: pagination
      description: "Collection endpoints must support pagination"
      pattern: "offset, limit query parameters"
      severity: warning
    - id: error-format
      description: "Error responses must follow RFC 7807"
      severity: error
```

**Apply in API Governance:**
```bash
anypoint-cli-v4 governance profile apply \
  --profile "Enterprise API Standards v2" \
  --environment Production \
  --scope "All APIs"
```

### How It Works
1. Define rules in a conformance profile published to Exchange
2. Apply the profile to environments or specific APIs
3. API specs are validated against the profile during design and deployment
4. Non-conforming APIs are flagged (warning) or blocked (error)

### Gotchas
- Profiles apply to API specs (RAML/OAS), not runtime behavior
- Severity levels: `error` blocks publication, `warning` allows with notification
- Custom rules require understanding of the governance rule syntax
- Profiles are versioned — updating a profile does not retroactively fail existing APIs

### Related
- [Custom Ruleset](../custom-ruleset/) — writing custom rules
- [CI/CD Validation](../cicd-validation/) — pipeline integration
