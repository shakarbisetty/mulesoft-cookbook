## Connector Compatibility Matrix for Java 17

> One non-compliant connector blocks your entire deployment. Here's the minimum version matrix for Java 17.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
One non-compliant connector blocks your entire deployment. Here's the minimum version matrix for Java 17.

### Solution
💡 Every connector must be Java 17-certified BEFORE upgrading the runtime. Run mvn dependency:tree to audit all connector versions at once.

### Keywords
connector-compatibility, dependency-tree, java-17-certified, version-matrix

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
