## CloudHub 2.0 Deployment with Java 17

> Deploying to CloudHub 2.0 with Java 17? Two config files need updating — pom.xml AND mule-artifact.json.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
Deploying to CloudHub 2.0 with Java 17? Two config files need updating — pom.xml AND mule-artifact.json.

### Solution
💡 CloudHub 2.0 does NOT support --add-opens JVM flags. All module-system issues must be fixed in code before deployment.

### Keywords
cloudhub2Deployment, javaVersion, mule-artifact.json, releaseChannel

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
