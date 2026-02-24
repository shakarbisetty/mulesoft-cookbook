# DevOps & CI/CD

[![MuleSoft](https://img.shields.io/badge/MuleSoft-DevOps-00A1E0.svg)](https://www.mulesoft.com/)
[![GitHub Actions](https://img.shields.io/badge/CI%2FCD-GitHub_Actions-2088FF.svg)](https://github.com/features/actions)

> 47 recipes for automating MuleSoft builds, tests, deployments, and monitoring.

---

## Tutorials (Start Here)

| Tutorial | Description | Difficulty |
|----------|-------------|------------|
| [GitHub Actions Pipeline](github-actions-pipeline/) | Complete CI/CD: build, test, deploy across DEV → QA → PROD | Intermediate |
| [MUnit in CI](munit-ci/) | Run MUnit tests, enforce coverage thresholds, generate reports | Beginner |
| [Maven Setup](maven-setup/) | Mule Maven Plugin config — authentication, deployment, Exchange | Beginner |
| [CloudHub 2.0 Deployment](cloudhub2-deployment/) | Architecture, networking, autoscaling, monitoring, migration | Intermediate |
| [Monitoring & Telemetry](monitoring-telemetry/) | DTS, OpenTelemetry, Grafana/Splunk/Datadog/New Relic integration | Advanced |

## Recipe Categories

| Category | Recipes | Description |
|----------|---------|-------------|
| [cicd-pipelines/](cicd-pipelines/) | 5 | GitLab CI, Azure DevOps, Jenkins, Bitbucket Pipelines, trunk-based dev |
| [environments/](environments/) | 5 | No-rebuild promotion, property externalization, secure properties, feature flags |
| [infrastructure/](infrastructure/) | 5 | Terraform, Ansible, Helm RTF, K8s Flex Gateway, CloudFormation |
| [secrets/](secrets/) | 5 | HashiCorp Vault, AWS Secrets Manager, Azure Key Vault, credential rotation |
| [testing/](testing/) | 4 | Docker integration, contract testing, Gatling performance, Newman E2E |
| [deployment/](deployment/) | 5 | Blue-green, canary release, rolling update, rollback strategies, zero-downtime DB |
| [rtf/](rtf/) | 4 | RTF on EKS, AKS, GKE, resource sizing |
| [anypoint-cli/](anypoint-cli/) | 4 | CLI v4 recipes, API Manager automation, Exchange publishing, org management |
| [observability/](observability/) | 4 | Distributed tracing OTEL, custom metrics Micrometer, log aggregation, SLO/SLI alerting |
| [compliance/](compliance/) | 1 | Dependency vulnerability scanning |

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
