## DataWeave Error Object Changes for Java 17

> Your error handling DataWeave scripts break on Java 17? Three error fields changed — here's the fix map.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
Your error handling DataWeave scripts break on Java 17? Three error fields changed — here's the fix map.

### Solution
💡 Java 17's module system breaks DataWeave's reflection-based access to internal Mule error objects. Update all three patterns to avoid silent failures.

### Keywords
error.errorType, error.errorMessage, error.childErrors, error-handling

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
