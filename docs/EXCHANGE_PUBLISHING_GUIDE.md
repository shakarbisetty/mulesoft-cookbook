# Anypoint Exchange Publishing Guide

How to publish DataWeave modules to Anypoint Exchange so MuleSoft developers can import them via Maven.

---

## Prerequisites

### 1. Anypoint Platform Account

- Sign up at [anypoint.mulesoft.com](https://anypoint.mulesoft.com) (free trial available)
- You need **Exchange Contributor** role in your organization
- Note your **Organization ID** — find it in: Access Management → Organization → Settings
- Your org ID is a UUID like `a1b2c3d4-e5f6-7890-abcd-ef1234567890`

### 2. Connected App (Recommended Auth Method)

Create a Connected App for CI/CD publishing:

1. Go to **Access Management → Connected Apps → Create App**
2. Choose **App acts on its own behalf (Client Credentials)**
3. Add scope: **Exchange Contributor** for your organization
4. Save the **Client ID** and **Client Secret**

### 3. Maven Settings

Add credentials to `~/.m2/settings.xml`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<settings>
    <servers>
        <server>
            <id>anypoint-exchange-v3</id>
            <username>~~~Client~~~</username>
            <password>{CLIENT_ID}~?~{CLIENT_SECRET}</password>
        </server>
    </servers>
</settings>
```

Replace `{CLIENT_ID}` and `{CLIENT_SECRET}` with your Connected App credentials.

**Alternative (username/password auth):**
```xml
<server>
    <id>anypoint-exchange-v3</id>
    <username>your-anypoint-username</username>
    <password>your-anypoint-password</password>
</server>
```

---

## Module POM Structure

Every DataWeave module published to Exchange needs a specific POM configuration.

### Key POM Elements

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>cb0ecddd-1505-4354-870f-45c4217384c2</groupId>
    <artifactId>dw-module-name</artifactId>
    <version>1.0.0</version>
    <packaging>mule-extension</packaging>

    <name>dw-module-name</name>
    <description>Description for Exchange listing</description>

    <parent>
        <groupId>org.mule.extensions</groupId>
        <artifactId>mule-modules-parent</artifactId>
        <version>1.3.2</version>
    </parent>

    <properties>
        <mule.version>4.4.0</mule.version>
        <munit.version>2.3.16</munit.version>
    </properties>

    <build>
        <plugins>
            <!-- Mule Maven Plugin -->
            <plugin>
                <groupId>org.mule.tools.maven</groupId>
                <artifactId>mule-maven-plugin</artifactId>
                <version>3.8.3</version>
                <extensions>true</extensions>
            </plugin>

            <!-- MUnit Maven Plugin -->
            <plugin>
                <groupId>com.mulesoft.munit.tools</groupId>
                <artifactId>munit-maven-plugin</artifactId>
                <version>${munit.version}</version>
                <executions>
                    <execution>
                        <id>test</id>
                        <phase>test</phase>
                        <goals>
                            <goal>test</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>

    <!-- Exchange Repository for deploy -->
    <distributionManagement>
        <repository>
            <id>anypoint-exchange-v3</id>
            <name>Anypoint Exchange</name>
            <url>https://maven.anypoint.mulesoft.com/api/v3/organizations/${project.groupId}/maven</url>
            <layout>default</layout>
        </repository>
    </distributionManagement>

    <!-- MuleSoft Repositories -->
    <repositories>
        <repository>
            <id>mulesoft-releases</id>
            <name>MuleSoft Releases</name>
            <url>https://repository.mulesoft.org/releases/</url>
        </repository>
        <repository>
            <id>mulesoft-snapshots</id>
            <name>MuleSoft Snapshots</name>
            <url>https://repository.mulesoft.org/snapshots/</url>
        </repository>
    </repositories>

    <pluginRepositories>
        <pluginRepository>
            <id>mulesoft-releases</id>
            <name>MuleSoft Releases</name>
            <url>https://repository.mulesoft.org/releases/</url>
        </pluginRepository>
    </pluginRepositories>
</project>
```

### Critical Notes

| Field | Value | Notes |
|-------|-------|-------|
| `groupId` | Your Anypoint Org ID | Must be the UUID from Access Management |
| `artifactId` | Module name | e.g., `dw-string-utils` |
| `packaging` | `mule-extension` | Required for DW modules |
| `distributionManagement.repository.id` | `anypoint-exchange-v3` | Must match `settings.xml` server ID |

---

## Directory Structure

```
dw-module-name/
├── pom.xml
├── README.md
├── src/
│   ├── main/
│   │   └── resources/
│   │       └── modules/
│   │           └── ModuleName.dwl       # The DW module file
│   └── test/
│       └── munit/
│           └── module-name-test-suite.xml  # MUnit tests
```

### DW Module File Convention

- Path must be `src/main/resources/modules/ModuleName.dwl`
- Module name should be PascalCase (e.g., `StringUtils.dwl`)
- Users import with: `import modules::StringUtils`

### Module File Structure

```dwl
%dw 2.0

/**
 * String utility functions for DataWeave.
 */

fun camelize(s: String): String =
    // implementation

fun snakeCase(s: String): String =
    // implementation
```

---

## MUnit Test Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:munit="http://www.mulesoft.org/schema/mule/munit"
      xmlns:munit-tools="http://www.mulesoft.org/schema/mule/munit-tools"
      xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="
        http://www.mulesoft.org/schema/mule/core http://www.mulesoft.org/schema/mule/core/current/mule.xsd
        http://www.mulesoft.org/schema/mule/munit http://www.mulesoft.org/schema/mule/munit/current/mule-munit.xsd
        http://www.mulesoft.org/schema/mule/munit-tools http://www.mulesoft.org/schema/mule/munit-tools/current/mule-munit-tools.xsd
        http://www.mulesoft.org/schema/mule/ee/core http://www.mulesoft.org/schema/mule/ee/core/current/mule-ee.xsd">

    <munit:config name="module-name-test-suite"/>

    <munit:test name="test-function-name"
                description="Description of what is being tested">
        <munit:execution>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[
                        %dw 2.0
                        import modules::ModuleName
                        output application/json
                        ---
                        ModuleName::functionName("input")
                    ]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </munit:execution>
        <munit:validation>
            <munit-tools:assert-that
                expression="#[payload]"
                is="#[MunitTools::equalTo('expected')]"/>
        </munit:validation>
    </munit:test>

</mule>
```

---

## Publishing Commands

### Build and Test Locally

```bash
mvn clean test
```

### Deploy to Exchange

```bash
mvn clean deploy
```

### Verify on Exchange

After deploy, your module appears at:
```
https://anypoint.mulesoft.com/exchange/cb0ecddd-1505-4354-870f-45c4217384c2/dw-module-name/
```

---

## Exchange Metadata

When the module is published, Exchange auto-generates a listing. To enhance it:

| Metadata | Where | Notes |
|----------|-------|-------|
| Name | `pom.xml` → `<name>` | Display name on Exchange |
| Description | `pom.xml` → `<description>` | Short description shown in search |
| Tags | Exchange UI (post-publish) | Add tags: `dataweave`, `utility`, `transformation` |
| Icon | Exchange UI (post-publish) | Upload a 200x200 PNG icon |
| Documentation | Exchange UI (post-publish) | Add usage examples, API docs |
| Categories | Exchange UI (post-publish) | Assign to relevant categories |

---

## How Users Import Your Module

### 1. Add Maven Dependency

```xml
<dependency>
    <groupId>cb0ecddd-1505-4354-870f-45c4217384c2</groupId>
    <artifactId>dw-string-utils</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

### 2. Add Exchange Repository

```xml
<repository>
    <id>anypoint-exchange-v3</id>
    <name>Anypoint Exchange</name>
    <url>https://maven.anypoint.mulesoft.com/api/v3/maven</url>
</repository>
```

### 3. Use in DataWeave

```dwl
%dw 2.0
import modules::StringUtils
output application/json
---
StringUtils::camelize("hello_world")  // "helloWorld"
```

---

## Version Strategy

| Version | When |
|---------|------|
| `1.0.0` | Initial release |
| `1.0.x` | Bug fixes, no API changes |
| `1.x.0` | New functions added (backward compatible) |
| `2.0.0` | Breaking changes (function signature changes, removals) |

Follow semantic versioning. Exchange supports multiple versions side by side.

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `401 Unauthorized` on deploy | Check `settings.xml` server ID matches POM, verify credentials |
| `403 Forbidden` | Verify Exchange Contributor role in Access Management |
| Module not found after deploy | Wait 1-2 minutes for Exchange indexing, check org ID |
| MUnit tests fail | Ensure DW module path is exactly `src/main/resources/modules/` |
| `mule-extension` packaging error | Add `mule-maven-plugin` with `<extensions>true</extensions>` |
