## Custom Connector Upgrade for Java 17

> Built a custom MuleSoft connector? Update mule-modules-parent and add the Java 17 annotation — or it won't deploy.

### When to Use
- Java 17 migration in MuleSoft projects
- CloudHub 2.0 deployments requiring Java 17
- Connector compatibility verification

### The Problem
Built a custom MuleSoft connector? Update mule-modules-parent and add the Java 17 annotation — or it won't deploy.

### Solution
💡 mule-modules-parent 1.9.0+ is required for Java 17 support. The @JavaVersionSupport annotation tells the runtime which Java versions your connector supports.

### Keywords
mule-modules-parent, JavaVersionSupport, custom-connector, Extension

### Related
- [Java 17 Migration Guide](https://github.com/shakarbisetty/mulesoft-cookbook/tree/main/migrations/java-17)
- [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
