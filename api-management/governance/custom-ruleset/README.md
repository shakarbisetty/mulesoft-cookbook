## Custom Governance Ruleset
> Write custom rules to enforce organization-specific API design conventions.

### When to Use
- Standard conformance profiles do not cover your requirements
- Enforcing naming conventions, security schemes, or response formats
- Industry-specific compliance rules (HIPAA, PCI, GDPR)

### Configuration / Code

**Custom ruleset (YAML):**
```yaml
rules:
  - id: require-https
    message: "All servers must use HTTPS"
    severity: error
    given: "$.servers[*].url"
    then:
      function: pattern
      functionOptions:
        match: "^https://"

  - id: require-contact
    message: "API must have contact information"
    severity: warning
    given: "$.info"
    then:
      field: contact
      function: truthy

  - id: no-numeric-ids-in-path
    message: "Path parameters should not be named id (use resourceId)"
    severity: warning
    given: "$.paths.*.*.parameters[?(@.in == path)]"
    then:
      field: name
      function: pattern
      functionOptions:
        notMatch: "^id$"
```

### How It Works
1. Rules use JSONPath (`given`) to select parts of the API spec
2. `then` applies a validation function (pattern, truthy, schema, etc.)
3. Severity determines if failures block or warn
4. Rulesets are published to Exchange and applied via governance profiles

### Gotchas
- JSONPath expressions can be complex — test against sample specs
- Rules run against the resolved spec (after $ref resolution)
- Performance: many complex rules slow down spec validation
- Custom functions are limited to built-in validation functions

### Related
- [Conformance Profile](../conformance-profile/) — applying rulesets
- [Naming Convention Rules](../naming-convention-rules/) — naming standards
