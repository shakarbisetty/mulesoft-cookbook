## Coverage Enforcement in CI/CD
> Enforce MUnit coverage thresholds in Maven builds and fail CI pipelines below 80%.

### When to Use
- You want to enforce minimum test coverage as a build gate
- You need to configure per-flow and per-application coverage thresholds
- You are setting up GitHub Actions (or other CI) to run MUnit tests and block merges on low coverage
- You need to understand MUnit coverage reports and what counts toward coverage

### Configuration / Code

**Maven pom.xml — MUnit Maven plugin with coverage configuration:**

```xml
<plugin>
    <groupId>com.mulesoft.munit.tools</groupId>
    <artifactId>munit-maven-plugin</artifactId>
    <version>${munit.version}</version>
    <executions>
        <execution>
            <id>test</id>
            <phase>test</phase>
            <goals>
                <goal>test</goal>
                <goal>coverage-report</goal>
            </goals>
        </execution>
    </executions>
    <configuration>
        <runtimeVersion>${app.runtime}</runtimeVersion>
        <coverage>
            <runCoverage>true</runCoverage>
            <failBuild>true</failBuild>

            <!-- Application-level threshold -->
            <requiredApplicationCoverage>80</requiredApplicationCoverage>

            <!-- Per-resource (flow file) threshold -->
            <requiredResourceCoverage>70</requiredResourceCoverage>

            <!-- Per-flow threshold -->
            <requiredFlowCoverage>60</requiredFlowCoverage>

            <!-- Formats: html for local review, json for CI parsing -->
            <formats>
                <format>html</format>
                <format>json</format>
            </formats>

            <!-- Exclude auto-generated or non-testable flows -->
            <ignoreFiles>
                <ignoreFile>global-error-handler.xml</ignoreFile>
                <ignoreFile>global-config.xml</ignoreFile>
            </ignoreFiles>
        </coverage>
    </configuration>
</plugin>
```

**Maven properties — version management:**

```xml
<properties>
    <munit.version>3.2.0</munit.version>
    <munit.input.directory>src/test/munit</munit.input.directory>
    <munit.output.directory>${basedir}/target/munit-reports</munit.output.directory>
    <app.runtime>4.6.0</app.runtime>
</properties>
```

**GitHub Actions workflow — `.github/workflows/munit-coverage.yml`:**

```yaml
name: MUnit Tests & Coverage

on:
  pull_request:
    branches: [main, develop]
  push:
    branches: [main]

env:
  MULE_EE_REPO_USER: ${{ secrets.MULE_EE_REPO_USER }}
  MULE_EE_REPO_PASSWORD: ${{ secrets.MULE_EE_REPO_PASSWORD }}

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'maven'

      - name: Configure Maven settings
        run: |
          mkdir -p ~/.m2
          cat > ~/.m2/settings.xml << 'SETTINGS'
          <settings>
            <servers>
              <server>
                <id>mule-enterprise</id>
                <username>${env.MULE_EE_REPO_USER}</username>
                <password>${env.MULE_EE_REPO_PASSWORD}</password>
              </server>
            </servers>
          </settings>
          SETTINGS

      - name: Run MUnit tests with coverage
        run: mvn clean test -Dmunit.test.coverage.failBuild=true

      - name: Upload coverage report
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: munit-coverage-report
          path: target/munit-reports/coverage/

      - name: Check coverage threshold
        if: always()
        run: |
          COVERAGE_FILE="target/munit-reports/coverage/munit-coverage.json"
          if [ -f "$COVERAGE_FILE" ]; then
            APP_COVERAGE=$(cat "$COVERAGE_FILE" | python3 -c "
          import json, sys
          data = json.load(sys.stdin)
          print(data.get('applicationCoverage', {}).get('coverage', 0))
          ")
            echo "Application coverage: ${APP_COVERAGE}%"
            if (( $(echo "$APP_COVERAGE < 80" | bc -l) )); then
              echo "FAIL: Coverage ${APP_COVERAGE}% is below 80% threshold"
              exit 1
            fi
            echo "PASS: Coverage ${APP_COVERAGE}% meets 80% threshold"
          else
            echo "WARNING: Coverage report not found"
            exit 1
          fi

      - name: Comment PR with coverage
        if: github.event_name == 'pull_request' && always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const coverageFile = 'target/munit-reports/coverage/munit-coverage.json';
            let body = '## MUnit Coverage Report\n\n';

            if (fs.existsSync(coverageFile)) {
              const data = JSON.parse(fs.readFileSync(coverageFile, 'utf8'));
              const appCov = data.applicationCoverage?.coverage || 0;
              const status = appCov >= 80 ? 'PASS' : 'FAIL';
              const emoji_indicator = appCov >= 80 ? 'passed' : 'failed';
              body += `| Metric | Coverage | Status |\n`;
              body += `|--------|----------|--------|\n`;
              body += `| Application | ${appCov}% | ${status} |\n`;

              if (data.files) {
                body += `\n### Per-File Coverage\n\n`;
                body += `| File | Coverage |\n|------|----------|\n`;
                for (const file of data.files) {
                  body += `| ${file.name} | ${file.coverage}% |\n`;
                }
              }
            } else {
              body += 'Coverage report not generated.\n';
            }

            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: body
            });
```

**Coverage report interpretation — what the numbers mean:**

```
Application Coverage: 85%  (all flows combined)
├── api-main.xml: 92%
│   ├── get-orders-flow: 100%     (all processors hit)
│   ├── post-order-flow: 88%      (error handler not tested)
│   └── delete-order-flow: 75%    (missing edge cases)
├── batch-processor.xml: 78%
│   ├── batch-main-flow: 80%
│   └── batch-error-flow: 60%     (needs more error tests)
└── global-config.xml: EXCLUDED   (via ignoreFiles)
```

Coverage counts each **processor** (logger, transform, HTTP request, etc.) as a unit. A flow with 10 processors where 8 are executed during tests has 80% coverage.

### How It Works
1. The `munit-maven-plugin` runs all tests in `src/test/munit/` during the Maven `test` phase
2. The `coverage-report` goal collects processor-level coverage data across all test executions
3. If any threshold (`requiredApplicationCoverage`, `requiredResourceCoverage`, `requiredFlowCoverage`) is not met, the build fails with a clear message showing which flow or file is below threshold
4. Coverage reports in HTML format provide a visual drill-down; JSON format enables CI script parsing
5. The GitHub Actions workflow runs tests, extracts coverage data, and posts results as a PR comment
6. `ignoreFiles` excludes configuration-only XML files that contain no testable logic

### Gotchas
- **Coverage excluding auto-generated flows**: APIkit auto-generates router flows and console flows. These inflate the denominator. Use `ignoreFiles` to exclude `api-router.xml` or similar files
- **APIkit router counting**: The APIkit router has many internal processors that are hard to test individually. Excluding the router file and testing your implementation flows gives more meaningful coverage numbers
- **Coverage is processor-based, not line-based**: Unlike code coverage in Java, MUnit counts Mule processors. A single DataWeave transform counts as one processor regardless of its complexity
- **Sub-flows share coverage**: Sub-flows called from multiple tests accumulate coverage. A sub-flow tested via one calling flow counts toward all files that reference it
- **Error handlers need explicit testing**: Error handler processors only count as covered if you explicitly trigger those error paths (see [Error Scenario Testing](../error-scenario-testing/))
- **Coverage report location**: Reports go to `target/munit-reports/coverage/`. This directory is cleaned on `mvn clean`. Archive it in CI before cleanup steps

### Related
- [Error Scenario Testing](../error-scenario-testing/)
- [Mock Data Generation](../mock-data-generation/)
- [Batch Job Testing](../batch-job-testing/)
- [Vibes MUnit Generation](../vibes-munit-generation/)
