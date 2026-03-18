## JAXB Removed in Java 17 — Jakarta Fix

> Getting NoClassDefFoundError on Java 17? JAXB was removed — here's the Jakarta replacement.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
Getting NoClassDefFoundError on Java 17? JAXB was removed — here's the Jakarta replacement.

### Solution
💡 JAXB was deprecated in Java 9 and fully removed in Java 11. Replace all javax.xml.bind imports with jakarta.xml.bind to fix Java 17 builds.

### Keywords
JAXB, jakarta.xml.bind, javax.xml.bind, NoClassDefFoundError

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
