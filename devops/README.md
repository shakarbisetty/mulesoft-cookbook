# DevOps & CI/CD

[![MuleSoft](https://img.shields.io/badge/MuleSoft-DevOps-00A1E0.svg)](https://www.mulesoft.com/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF.svg)](https://github.com/features/actions)

> Automate MuleSoft builds, tests, deployments, and monitoring.

---

## What's Here

| Tutorial | Description | Difficulty |
|----------|-------------|------------|
| [GitHub Actions Pipeline](github-actions-pipeline/) | Complete CI/CD: build, test, deploy across DEV → QA → PROD | Intermediate |
| [MUnit in CI](munit-ci/) | Run MUnit tests, enforce coverage thresholds, generate reports | Beginner |
| [Maven Setup](maven-setup/) | Mule Maven Plugin config — authentication, deployment, Exchange | Beginner |
| [CloudHub 2.0 Deployment](cloudhub2-deployment/) | Architecture, networking, autoscaling, monitoring, migration | Intermediate |

## Coming Soon

| Topic | Description |
|-------|-------------|
| Direct Telemetry Stream | Real-time monitoring with external observability tools |
| Environment Promotion | Artifact-based promotion patterns (no rebuild) |
| Secrets Management | Secure credential handling across environments |

## Prerequisites

- GitHub account with Actions enabled
- Anypoint Platform Connected App credentials
- Maven 3.8+ and Java 21
- Mule Maven Plugin 4.6.0

---

## Quick Reference

```bash
# Build
mvn clean package

# Test with coverage
mvn clean test

# Deploy to CloudHub 2.0
mvn clean deploy -DmuleDeploy -s .maven/settings.xml

# Deploy with environment profile
mvn clean deploy -DmuleDeploy -Pprod -s .maven/settings.xml
```

---

## Related

- [MuleSoft CI/CD with GitHub Actions](https://blogs.mulesoft.com/dev-guides/automate-ci-cd-pipelines-with-github-actions-and-anypoint-cli/)
- [CloudHub 2.0 Documentation](https://docs.mulesoft.com/cloudhub-2/)
- [Mule Maven Plugin Reference](https://docs.mulesoft.com/mule-runtime/latest/mmp-concept)
- [Anypoint CLI v4](https://docs.mulesoft.com/anypoint-cli/latest/)

---

Part of [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
