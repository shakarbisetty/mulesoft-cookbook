## javax.* API Replacements for Java 17

> It's not just JAXB — three more javax packages were removed. Here's the full replacement table.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
It's not just JAXB — three more javax packages were removed. Here's the full replacement table.

### Solution
💡 javax.activation, javax.annotation, and javax.xml.ws are all gone in Java 17. Each maps to a Jakarta equivalent — update both pom.xml and imports.

### Keywords
java-17, mulesoft, migration

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
