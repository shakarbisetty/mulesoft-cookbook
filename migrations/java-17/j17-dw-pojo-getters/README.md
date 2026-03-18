## DataWeave POJO Access — Getters Required on Java 17

> DataWeave accessing private Java fields breaks on Java 17. Add getters and setters to every POJO or your flows crash.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
DataWeave accessing private Java fields breaks on Java 17. Add getters and setters to every POJO or your flows crash.

### Solution
💡 In Java 8 DataWeave accessed private fields via reflection. Java 17 blocks this — public getters, setters, AND a no-arg constructor are required.

### Keywords
POJO, getter, setter, reflection

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
