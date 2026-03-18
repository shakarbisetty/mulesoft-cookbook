## POM.xml Changes for Mule 4.9 + Java 17

> Upgrading to Mule 4.9 LTS? These four pom.xml properties must change — miss one and it breaks.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
Upgrading to Mule 4.9 LTS? These four pom.xml properties must change — miss one and it breaks.

### Solution
💡 Mule 4.9 LTS runs on Java 17 ONLY — no Java 8 or 11 fallback. Set both maven.compiler.source and target to 17 or compilation fails.

### Keywords
app.runtime, mule.maven.plugin, munit.version, maven.compiler

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
