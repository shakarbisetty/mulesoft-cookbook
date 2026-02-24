## API Naming Convention Rules
> Enforce consistent naming for endpoints, query params, and response fields.

### When to Use
- Standardizing API naming across the organization (camelCase, kebab-case, etc.)
- Preventing inconsistent field names in response schemas
- Automated naming checks in API design tools

### Configuration / Code

```yaml
rules:
  - id: kebab-case-paths
    message: "URL paths must use kebab-case"
    severity: error
    given: "$.paths"
    then:
      function: pattern
      functionOptions:
        match: "^(/[a-z][a-z0-9-]*)+(/\\{[a-zA-Z]+\\})*$"

  - id: camelcase-properties
    message: "Response properties must use camelCase"
    severity: error
    given: "$.components.schemas.*.properties"
    then:
      function: pattern
      functionOptions:
        match: "^[a-z][a-zA-Z0-9]*$"

  - id: plural-collection-names
    message: "Collection resource names should be plural"
    severity: warning
    given: "$.paths"
    then:
      function: pattern
      functionOptions:
        match: "(s|ies|data|info)(/|$|\\{)"
```

### How It Works
1. Rules target path segments, property names, and parameter names
2. Regex patterns enforce the naming convention (kebab-case, camelCase)
3. Rules run during spec validation in design time and CI/CD
4. Consistent naming improves API discoverability and SDK generation

### Gotchas
- Regex for naming rules can be tricky — test edge cases (acronyms, numbers)
- Existing APIs may not conform — use warning severity during migration
- SDK generators benefit from consistent naming — camelCase for JSON, kebab-case for URLs
- Plural detection is heuristic — "status" vs "statuses" may need exceptions

### Related
- [Custom Ruleset](../custom-ruleset/) — writing custom rules
- [Conformance Profile](../conformance-profile/) — applying rules
