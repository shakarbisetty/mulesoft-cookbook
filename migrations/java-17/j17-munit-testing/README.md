## MUnit Testing Strategy for Java 17 Migration

> Don't deploy blind — test with LOOSE then STRICT. Two-pass MUnit strategy catches Java 17 issues before production.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
Don't deploy blind — test with LOOSE then STRICT. Two-pass MUnit strategy catches Java 17 issues before production.

### Solution
💡 LOOSE enforcement shows warnings without failing. STRICT is the Mule 4.9 default. Replace PowerMock with Mockito 5.x — PowerMock is incompatible with sealed modules.

### Keywords
munit, LOOSE, STRICT, PowerMock, Mockito

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
