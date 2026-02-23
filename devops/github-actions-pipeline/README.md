# GitHub Actions Pipeline for MuleSoft

> Complete CI/CD: build, test with MUnit, deploy to CloudHub 2.0 across DEV → QA → PROD.

## Overview

This tutorial builds a production-ready GitHub Actions pipeline that:
1. Builds your Mule app and runs MUnit tests on every push/PR
2. Deploys to **DEV** from `develop` branch
3. Deploys to **QA** from `release/*` branches
4. Deploys to **PROD** from `main` with manual approval gate

## Prerequisites

- Anypoint Platform account
- Connected App with client credentials (see [Maven Setup](../maven-setup/))
- GitHub repository with Actions enabled

## Git Branching Strategy

```
feature/* ──────────────────────┐
                                 ▼
                            develop ──► DEV (auto on push)
                                 │
                    ┌────────────┘
                    ▼
              release/v1.x ──► QA (auto on push)
                    │
                    ▼
                  main ──► PROD (manual approval gate)
```

## Step 1: Create `settings.xml`

This file goes in `.maven/settings.xml` — checked into your repo. Secrets are injected from environment variables at runtime.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings>
  <servers>
    <server>
      <id>anypoint-exchange-v3</id>
      <username>~~~Client~~~</username>
      <password>${env.CONNECTED_APP_CLIENT_ID}~?~${env.CONNECTED_APP_CLIENT_SECRET}</password>
    </server>
  </servers>
  <pluginGroups>
    <pluginGroup>org.mule.tools</pluginGroup>
  </pluginGroups>
</settings>
```

The `~~~Client~~~` username tells the Mule Maven Plugin to use Connected App authentication. The `clientId~?~clientSecret` format is required.

## Step 2: Configure GitHub Secrets

Go to **Settings > Secrets and variables > Actions** and add:

| Secret | Description |
|--------|-------------|
| `CONNECTED_APP_CLIENT_ID` | Connected App client ID from Anypoint |
| `CONNECTED_APP_CLIENT_SECRET` | Connected App client secret |
| `DEV_DB_PASSWORD` | DEV environment secure properties |
| `QA_DB_PASSWORD` | QA environment secure properties |
| `PROD_DB_PASSWORD` | PROD environment secure properties |

And **Variables** (non-sensitive):

| Variable | Example |
|----------|---------|
| `APP_NAME` | `my-payment-api` |
| `CH2_TARGET` | `Cloudhub-US-East-1` |

## Step 3: Configure GitHub Environments

For the PROD manual approval gate:

1. Go to **Settings > Environments**
2. Create environment `production`
3. Enable **Required reviewers** and add team leads
4. Optionally add deployment branch rule: `main` only

## Step 4: Create the Workflow

### `.github/workflows/cicd.yml`

```yaml
name: MuleSoft CI/CD Pipeline

on:
  push:
    branches: [develop, release/**, main]
  pull_request:
    branches: [develop, main]

jobs:

  # ─── Build & Test ───────────────────────────────────
  build-and-test:
    name: Build & MUnit Tests
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Java 21
        uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Run MUnit tests
        run: mvn clean test -s .maven/settings.xml
        env:
          CONNECTED_APP_CLIENT_ID: ${{ secrets.CONNECTED_APP_CLIENT_ID }}
          CONNECTED_APP_CLIENT_SECRET: ${{ secrets.CONNECTED_APP_CLIENT_SECRET }}

      - name: Upload MUnit coverage report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: munit-coverage-report
          path: target/site/munit/coverage/

      - name: Upload test results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: surefire-reports
          path: target/surefire-reports/

  # ─── Deploy to DEV ─────────────────────────────────
  deploy-dev:
    name: Deploy to DEV
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/develop' && github.event_name == 'push'
    environment:
      name: dev
      url: https://${{ vars.APP_NAME }}-dev.cloudhub.io

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Deploy to DEV
        run: |
          mvn clean deploy -DmuleDeploy -s .maven/settings.xml \
            -Denvironment=DEV \
            -DappName=${{ vars.APP_NAME }}-dev \
            -Dtarget=${{ vars.CH2_TARGET }}
        env:
          CONNECTED_APP_CLIENT_ID: ${{ secrets.CONNECTED_APP_CLIENT_ID }}
          CONNECTED_APP_CLIENT_SECRET: ${{ secrets.CONNECTED_APP_CLIENT_SECRET }}

  # ─── Deploy to QA ──────────────────────────────────
  deploy-qa:
    name: Deploy to QA
    runs-on: ubuntu-latest
    needs: build-and-test
    if: startsWith(github.ref, 'refs/heads/release/') && github.event_name == 'push'
    environment:
      name: qa
      url: https://${{ vars.APP_NAME }}-qa.cloudhub.io

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Deploy to QA
        run: |
          mvn clean deploy -DmuleDeploy -s .maven/settings.xml \
            -Denvironment=QA \
            -DappName=${{ vars.APP_NAME }}-qa \
            -Dtarget=${{ vars.CH2_TARGET }}
        env:
          CONNECTED_APP_CLIENT_ID: ${{ secrets.CONNECTED_APP_CLIENT_ID }}
          CONNECTED_APP_CLIENT_SECRET: ${{ secrets.CONNECTED_APP_CLIENT_SECRET }}

  # ─── Deploy to PROD (manual approval) ─────────────
  deploy-prod:
    name: Deploy to PROD
    runs-on: ubuntu-latest
    needs: build-and-test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    environment:
      name: production
      url: https://${{ vars.APP_NAME }}.cloudhub.io

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'
          cache: maven

      - name: Deploy to PROD
        run: |
          mvn clean deploy -DmuleDeploy -s .maven/settings.xml \
            -Denvironment=Production \
            -DappName=${{ vars.APP_NAME }} \
            -Dtarget=${{ vars.CH2_TARGET }} \
            -Dreplicas=2 \
            -DvCores=0.5
        env:
          CONNECTED_APP_CLIENT_ID: ${{ secrets.CONNECTED_APP_CLIENT_ID }}
          CONNECTED_APP_CLIENT_SECRET: ${{ secrets.CONNECTED_APP_CLIENT_SECRET }}

      - name: Tag release
        run: |
          VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
          git tag "v${VERSION}"
          git push origin "v${VERSION}"
```

## Environment Promotion via `workflow_dispatch`

For manual promotions (deploy a specific version to any environment):

```yaml
name: Promote to Environment

on:
  workflow_dispatch:
    inputs:
      target_environment:
        description: Target environment
        required: true
        type: choice
        options: [qa, staging, production]
      app_version:
        description: Artifact version (e.g., 1.2.3)
        required: true

jobs:
  promote:
    runs-on: ubuntu-latest
    environment: ${{ inputs.target_environment }}

    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '21'

      - name: Deploy pre-built artifact
        run: |
          mvn mule:deploy \
            -Dmule.artifact=target/my-app-${{ inputs.app_version }}-mule-application.jar \
            -Denvironment=${{ inputs.target_environment }} \
            -DappName=${{ vars.APP_NAME }}-${{ inputs.target_environment }} \
            -s .maven/settings.xml
        env:
          CONNECTED_APP_CLIENT_ID: ${{ secrets.CONNECTED_APP_CLIENT_ID }}
          CONNECTED_APP_CLIENT_SECRET: ${{ secrets.CONNECTED_APP_CLIENT_SECRET }}
```

## Maven Profiles for Environment-Specific Config

Instead of passing `-D` flags, use Maven profiles in `pom.xml`:

```xml
<profiles>
  <profile>
    <id>dev</id>
    <properties>
      <environment>DEV</environment>
      <appName>my-api-dev</appName>
      <replicas>1</replicas>
      <vCores>0.1</vCores>
    </properties>
  </profile>
  <profile>
    <id>prod</id>
    <properties>
      <environment>Production</environment>
      <appName>my-api</appName>
      <replicas>2</replicas>
      <vCores>0.5</vCores>
    </properties>
  </profile>
</profiles>
```

Activate in pipeline: `mvn clean deploy -DmuleDeploy -Pprod`

## Common Gotchas

- **`~~~Client~~~` is literal** — this exact string must be the `<username>` for Connected App auth
- **`clientId~?~clientSecret` separator is `~?~`** — not a colon, not a space
- **Java 21 for Mule Maven Plugin 4.6.0** — older Java versions cause compatibility issues
- **`pathRewrite` placement** — in plugin v4.4.0+, must be nested inside `<http><inbound>`, not at parent level
- **GitHub Environment reviewers** — configure _before_ your first PROD deploy, or the job will auto-approve
- **Cache Maven dependencies** — saves 2-3 minutes per build; use `hashFiles('**/pom.xml')` as cache key

## References

- [CI/CD with GitHub Actions — MuleSoft Labs](https://mulesoft-labs.dev/codelabs/cicd-with-github-actions/)
- [Automate CI/CD with GitHub Actions — MuleSoft Blog](https://blogs.mulesoft.com/dev-guides/automate-ci-cd-pipelines-with-github-actions-and-anypoint-cli/)
- [Deploy to CloudHub 2.0 with Maven](https://docs.mulesoft.com/mule-runtime/latest/deploy-to-cloudhub-2)
- [Mule Maven Plugin Reference](https://docs.mulesoft.com/mule-runtime/latest/mmp-concept)
