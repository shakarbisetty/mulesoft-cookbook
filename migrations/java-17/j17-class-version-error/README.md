## UnsupportedClassVersionError — Java Version Mismatch

> UnsupportedClassVersionError class file version 61.0? Your dependency was compiled for a different Java version.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
UnsupportedClassVersionError class file version 61.0? Your dependency was compiled for a different Java version.

### Solution
💡 Java 8=52, Java 11=55, Java 17=61. All dependencies must be compiled for Java 17 or lower — recompile or update the library.

### Keywords
UnsupportedClassVersionError, class-file-version, dependency-tree, java-version

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
