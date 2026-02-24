## Runtime API Conformance
> Monitor deployed APIs for drift between spec and actual behavior.

### When to Use
- Detecting undocumented endpoints or response fields
- Ensuring deployed APIs match their published specifications
- Compliance auditing for regulated environments

### Configuration / Code

**API Manager runtime validation:**
```yaml
policyRef:
  name: schema-validation
configuration:
  specUrl: "exchange://org-id/orders-api/1.0.0/api.raml"
  validateRequest: true
  validateResponse: true
  logViolations: true
  blockOnViolation: false
```

### How It Works
1. Schema validation policy loads the API spec from Exchange
2. Incoming requests are validated against the spec (path, params, body)
3. Outgoing responses are validated against the spec (status, schema)
4. Violations are logged and optionally blocked

### Gotchas
- Response validation adds latency — consider enabling only in staging
- `blockOnViolation: true` in production may break existing clients
- Spec must be kept in sync with the deployed API version
- Runtime validation catches drift but does not fix it — follow up with spec updates

### Related
- [RAML/OAS Validation](../../error-handling/validation/raml-oas-validation/) — request validation
- [Conformance Profile](../conformance-profile/) — design-time governance
