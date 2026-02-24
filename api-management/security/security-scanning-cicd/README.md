## Security Scanning in CI/CD
> Integrate SAST, DAST, dependency scanning, and API spec linting into your MuleSoft CI/CD pipeline to catch vulnerabilities before deployment.

### When to Use
- Setting up a CI/CD pipeline for MuleSoft applications that requires security gates
- Compliance mandates automated vulnerability scanning before production deployment
- Adopting shift-left security practices for API development
- Need to scan dependencies for known CVEs (Log4Shell, Spring4Shell, etc.)

### Configuration / Code

#### Maven Plugin — OWASP Dependency-Check

Add to your Mule project's `pom.xml` to scan all dependencies for known vulnerabilities.

```xml
<!-- pom.xml — add to <build><plugins> section -->
<plugin>
    <groupId>org.owasp</groupId>
    <artifactId>dependency-check-maven</artifactId>
    <version>9.0.9</version>
    <configuration>
        <!-- Fail build if any CVE has CVSS score >= 7.0 (High) -->
        <failBuildOnCVSS>7</failBuildOnCVSS>
        <!-- Scan all project dependencies including transitive -->
        <skipProvidedScope>false</skipProvidedScope>
        <skipRuntimeScope>false</skipRuntimeScope>
        <!-- Suppress known false positives -->
        <suppressionFiles>
            <suppressionFile>owasp-suppressions.xml</suppressionFile>
        </suppressionFiles>
        <!-- Output formats -->
        <formats>
            <format>HTML</format>
            <format>JSON</format>
        </formats>
        <outputDirectory>${project.build.directory}/owasp-reports</outputDirectory>
        <!-- NVD API key for faster downloads (optional but recommended) -->
        <nvdApiKey>${env.NVD_API_KEY}</nvdApiKey>
    </configuration>
</plugin>
```

#### OWASP Suppression File

```xml
<!-- owasp-suppressions.xml — suppress verified false positives -->
<?xml version="1.0" encoding="UTF-8"?>
<suppressions xmlns="https://jeremylong.github.io/DependencyCheck/dependency-suppression.1.3.xsd">
    <!-- Example: suppress a false positive for mule-runtime internal dependency -->
    <suppress>
        <notes>
            False positive — this CVE applies to standalone Spring Boot,
            not the embedded version in Mule Runtime. Verified 2026-02-24.
        </notes>
        <cve>CVE-2024-XXXXX</cve>
    </suppress>
</suppressions>
```

#### GitHub Actions Workflow — Scan, Gate, Deploy

```yaml
# .github/workflows/security-pipeline.yml
name: Security Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  MAVEN_OPTS: "-Xmx1024m"

jobs:
  # Stage 1: Static Analysis + Dependency Scan
  security-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'maven'

      - name: Cache NVD data
        uses: actions/cache@v4
        with:
          path: ~/.m2/repository/org/owasp/dependency-check-data
          key: nvd-${{ runner.os }}-${{ hashFiles('**/pom.xml') }}
          restore-keys: nvd-${{ runner.os }}-

      - name: Run OWASP Dependency Check
        run: mvn dependency-check:check -DnvdApiKey=${{ secrets.NVD_API_KEY }}
        continue-on-error: false

      - name: Upload Dependency Check Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: owasp-dependency-report
          path: target/owasp-reports/

      - name: Run MUnit Tests
        run: mvn test -Dmunit.test.coverage.failBuild=true -Dmunit.test.coverage.requiredApplicationCoverage=80

      - name: Upload MUnit Reports
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: munit-reports
          path: target/site/munit/

  # Stage 2: API Spec Linting
  api-spec-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install Spectral
        run: npm install -g @stoplight/spectral-cli

      - name: Lint RAML/OAS Specs
        run: |
          # Find all API spec files
          for spec in $(find . -name "*.raml" -o -name "*.yaml" -o -name "*.json" | grep -i "api\|spec\|openapi\|swagger"); do
            echo "Linting: $spec"
            spectral lint "$spec" --ruleset .spectral.yaml --fail-severity warn || exit 1
          done

      - name: Upload Lint Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: spectral-lint-report
          path: spectral-report.json

  # Stage 3: Deploy (only after security gates pass)
  deploy:
    needs: [security-scan, api-spec-lint]
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'maven'

      - name: Deploy to CloudHub 2.0
        run: |
          mvn deploy -DmuleDeploy \
            -Danypoint.username=${{ secrets.ANYPOINT_USERNAME }} \
            -Danypoint.password=${{ secrets.ANYPOINT_PASSWORD }} \
            -Danypoint.environment=Production \
            -Danypoint.businessGroup=${{ secrets.ANYPOINT_BG }} \
            -Dcloudhub2.replicas=2 \
            -Dcloudhub2.vcores=0.2
```

#### Spectral Ruleset for API Specs

```yaml
# .spectral.yaml — custom rules for MuleSoft API specs
extends:
  - spectral:oas
  - spectral:asyncapi

rules:
  # Security Rules
  operation-security-defined:
    description: Every operation must have a security scheme
    severity: error
    given: "$.paths[*][get,post,put,patch,delete]"
    then:
      field: security
      function: truthy

  no-http-in-servers:
    description: All server URLs must use HTTPS
    severity: error
    given: "$.servers[*].url"
    then:
      function: pattern
      functionOptions:
        match: "^https://"

  # Data Exposure Rules
  no-additionalProperties-allowed:
    description: Response schemas should not allow additional properties
    severity: warn
    given: "$.paths[*][*].responses[*].content[*].schema"
    then:
      field: additionalProperties
      function: falsy

  # Rate Limiting
  rate-limit-headers:
    description: 429 response should be documented
    severity: warn
    given: "$.paths[*][*].responses"
    then:
      field: "429"
      function: truthy

  # PII Rules
  sensitive-field-description:
    description: Fields named ssn, password, secret should have x-sensitive marker
    severity: warn
    given: "$..[?(@ property.match(/ssn|password|secret|token|key/i))]"
    then:
      field: x-sensitive
      function: truthy
```

#### DAST with OWASP ZAP (Post-Deploy)

```yaml
# .github/workflows/dast-scan.yml
name: DAST Scan

on:
  workflow_run:
    workflows: ["Security Pipeline"]
    types: [completed]
    branches: [main]

jobs:
  zap-scan:
    runs-on: ubuntu-latest
    if: ${{ github.event.workflow_run.conclusion == 'success' }}
    steps:
      - uses: actions/checkout@v4

      - name: ZAP API Scan
        uses: zaproxy/action-api-scan@v0.7.0
        with:
          target: "https://api.staging.example.com/api/v1"
          rules_file_name: "zap-rules.tsv"
          cmd_options: >
            -f openapi
            -O https://api.staging.example.com/api/v1/openapi.json
            -z "-config api.addrs.addr(0).name=api.staging.example.com
                -config api.addrs.addr(0).enabled=true"

      - name: Upload ZAP Report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: zap-report
          path: report_html.html
```

### How It Works
1. **Dependency scanning** — the OWASP Dependency-Check Maven plugin downloads the NVD database and compares all project dependencies (including transitive) against known CVEs; builds fail if any High/Critical CVEs are found
2. **API spec linting** — Spectral validates RAML/OAS specs against security rules (HTTPS enforcement, security scheme requirement, PII field markers)
3. **Security gate** — the deploy job has `needs: [security-scan, api-spec-lint]`, so deployment is blocked if any scan fails
4. **DAST scanning** — after deployment to staging, OWASP ZAP runs an active scan against the live API to find runtime vulnerabilities the static scans missed
5. **Suppression management** — verified false positives are tracked in `owasp-suppressions.xml` with notes explaining why each was suppressed

### Gotchas
- **False positives overwhelming the team** — without a suppression file, the OWASP dependency-check will flag MuleSoft internal dependencies that are not exploitable in context; maintain and review the suppression file regularly
- **Scan time in CI pipeline** — the NVD database download can take 10+ minutes on first run; cache the NVD data between builds (the workflow above includes this)
- **NVD API rate limits** — without an NVD API key, downloads are severely throttled; register for a free key at https://nvd.nist.gov/developers/request-an-api-key
- **Spectral and RAML** — Spectral has limited RAML support; for RAML specs, consider converting to OAS first or using AMF-based validators
- **DAST in production** — never run active DAST scans against production; use a staging environment that mirrors production
- **Mule connector vulnerabilities** — connectors downloaded from Exchange may not appear in NVD; supplement with Anypoint Security advisories
- **Pipeline secrets** — never log Anypoint credentials or API keys in CI output; use GitHub Secrets and mask sensitive values

### Related
- [OWASP API Top 10 Mapping](../owasp-api-top10-mapping/)
- [Injection Prevention](../injection-prevention/)
- [GitHub Actions CI/CD Pipeline](../../../devops/github-actions-pipeline/)
- [MUnit CI Integration](../../../devops/munit-ci/)
