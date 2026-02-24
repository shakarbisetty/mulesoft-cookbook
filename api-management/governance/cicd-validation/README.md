## API Governance in CI/CD
> Validate API specs against governance rules as part of the build pipeline.

### When to Use
- Shift-left API governance — catch issues before deployment
- Automated spec validation on pull requests
- Blocking non-conforming APIs from reaching production

### Configuration / Code

**GitHub Actions workflow:**
```yaml
name: API Governance Check
on:
  pull_request:
    paths: ["src/main/resources/api/**"]

jobs:
  governance:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Install Anypoint CLI
      run: npm install -g anypoint-cli-v4
    - name: Validate API Spec
      run: |
        anypoint-cli-v4 governance validate \
          --spec src/main/resources/api/api.raml \
          --profile "Enterprise API Standards v2" \
          --fail-on-error
      env:
        ANYPOINT_CLIENT_ID: ${{ secrets.ANYPOINT_CLIENT_ID }}
        ANYPOINT_CLIENT_SECRET: ${{ secrets.ANYPOINT_CLIENT_SECRET }}
```

### How It Works
1. PR triggers governance check when API spec files change
2. Anypoint CLI validates the spec against the configured profile
3. Errors fail the pipeline; warnings are reported as annotations
4. Developers fix governance violations before merge

### Gotchas
- CLI credentials need `API Governance Viewer` role at minimum
- Validation requires network access to Exchange (for profile rules)
- Spec must be syntactically valid before governance rules apply
- Cache the CLI installation step for faster pipeline runs

### Related
- [Conformance Profile](../conformance-profile/) — profile definition
- [Custom Ruleset](../custom-ruleset/) — custom rules
