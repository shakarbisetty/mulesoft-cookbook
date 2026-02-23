# MUnit in CI/CD Pipelines

> Run MUnit tests, enforce coverage thresholds, and generate reports in automated pipelines.

## Overview

MUnit is MuleSoft's testing framework for Mule applications. In CI/CD pipelines, it runs as a Maven plugin — no special tools or agents needed. This tutorial covers configuration for coverage enforcement, report generation, and pipeline integration.

## Prerequisites

- Mule Maven Plugin 4.4.0+
- MUnit Maven Plugin (matches your `munit.version`)
- Java 21

## MUnit Maven Plugin Configuration

Add to your `pom.xml`:

```xml
<properties>
  <munit.version>2.3.18</munit.version>
</properties>

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

    <!-- Coverage enforcement -->
    <coverage>
      <runCoverage>true</runCoverage>
      <failBuild>true</failBuild>
      <requiredApplicationCoverage>80</requiredApplicationCoverage>
      <requiredResourceCoverage>60</requiredResourceCoverage>
      <requiredFlowCoverage>60</requiredFlowCoverage>
      <formats>
        <format>console</format>
        <format>html</format>
        <format>json</format>
      </formats>
      <!-- Exclude infrastructure flows -->
      <ignoreFlows>
        <ignoreFlow>global-error-handler</ignoreFlow>
        <ignoreFlow>health-check-flow</ignoreFlow>
      </ignoreFlows>
      <ignoreFiles>
        <ignoreFile>global-config.xml</ignoreFile>
      </ignoreFiles>
    </coverage>

    <!-- Dynamic ports avoid CI collision -->
    <dynamicPorts>
      <dynamicPort>http.port</dynamicPort>
    </dynamicPorts>

    <!-- Test runtime properties -->
    <systemPropertyVariables>
      <mule.env>test</mule.env>
    </systemPropertyVariables>

    <!-- Surefire XML for CI test reporters -->
    <enableSurefireReports>true</enableSurefireReports>
    <redirectTestOutputToFile>true</redirectTestOutputToFile>

    <!-- JVM memory for large test suites -->
    <argLines>
      <argLine>-Xmx1024m</argLine>
    </argLines>

  </configuration>
</plugin>
```

## Coverage Thresholds

Three levels of coverage enforcement:

| Level | Element | What It Measures |
|-------|---------|------------------|
| Application | `requiredApplicationCoverage` | All flows across all config files combined |
| Resource | `requiredResourceCoverage` | Each XML config file individually |
| Flow | `requiredFlowCoverage` | Each flow individually |

When `failBuild` is `true`, the pipeline fails if any threshold is not met.

## Running Tests

```bash
# Run all tests with coverage
mvn clean test

# Run specific test suite
mvn clean test -Dmunit.test=.*order-api-test.*

# Run specific test within a suite
mvn clean test -Dmunit.test=.*suite.*#.*validate-payload.*

# Run tests by tag
mvn clean test -Dmunit.tags=smoke

# Skip tests during packaging
mvn clean package -DskipMunitTests

# Override thresholds at runtime
mvn clean test -Dcoverage.application=90 -Dcoverage.flow=70
```

## Report Locations

| Format | Path | Use |
|--------|------|-----|
| HTML | `target/site/munit/coverage/` | Human-readable dashboard |
| JSON | `target/site/munit/coverage/coverage.json` | Machine-parseable |
| Surefire XML | `target/surefire-reports/` | CI test reporters (GitHub Actions) |
| SonarQube | `target/sonar-reports/` | SonarQube integration |

## GitHub Actions Integration

```yaml
- name: Run MUnit tests
  run: mvn clean test -s .maven/settings.xml
  env:
    CONNECTED_APP_CLIENT_ID: ${{ secrets.CONNECTED_APP_CLIENT_ID }}
    CONNECTED_APP_CLIENT_SECRET: ${{ secrets.CONNECTED_APP_CLIENT_SECRET }}

- name: Upload coverage report
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: munit-coverage
    path: target/site/munit/coverage/

- name: Upload test results
  uses: actions/upload-artifact@v4
  if: always()
  with:
    name: test-results
    path: target/surefire-reports/
```

The `if: always()` ensures reports are uploaded even when tests fail.

## Excluding Flows from Coverage

Some flows shouldn't count toward coverage:

```xml
<coverage>
  <!-- By flow name -->
  <ignoreFlows>
    <ignoreFlow>global-error-handler</ignoreFlow>
    <ignoreFlow>health-check-flow</ignoreFlow>
    <ignoreFlow>scheduler-trigger</ignoreFlow>
  </ignoreFlows>
  <!-- By config file -->
  <ignoreFiles>
    <ignoreFile>global-config.xml</ignoreFile>
    <ignoreFile>mule-artifact.json</ignoreFile>
  </ignoreFiles>
</coverage>
```

## Common Gotchas

- **Dynamic ports are essential in CI** — parallel builds on the same runner fight over port 8081 without `<dynamicPorts>`
- **`failBuild` defaults to `false`** — you must explicitly set it to `true` for coverage enforcement
- **Surefire reports must be enabled** — `enableSurefireReports` defaults to `false`; without it, GitHub Actions can't parse test results
- **Memory for large suites** — default JVM heap may be too small; add `-Xmx1024m` or higher
- **`redirectTestOutputToFile`** — keeps CI logs clean by routing verbose Mule startup logs to files

## References

- [MUnit Maven Plugin](https://docs.mulesoft.com/munit/latest/munit-maven-plugin)
- [Coverage Configuration](https://docs.mulesoft.com/munit/2.3/coverage-maven-concept)
- [MUnit Documentation](https://docs.mulesoft.com/munit/latest/)
