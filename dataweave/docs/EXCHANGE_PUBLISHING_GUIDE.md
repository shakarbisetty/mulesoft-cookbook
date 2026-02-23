# Anypoint Exchange Publishing Guide

How to publish DataWeave modules to Anypoint Exchange so MuleSoft developers can import them via Maven.

---

## Prerequisites

### 1. Anypoint Platform Account

- Sign up at [anypoint.mulesoft.com](https://anypoint.mulesoft.com) (free trial available)
- You need **Exchange Contributor** role in your organization
- Note your **Organization ID** — find it in: Access Management > Organization > Settings
- Your org ID is a UUID like `cb0ecddd-1505-4354-870f-45c4217384c2`

### 2. Connected App (Recommended Auth Method)

Create a Connected App for CI/CD publishing:

1. Go to **Access Management > Connected Apps > Create App**
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
    <packaging>jar</packaging>

    <name>dw-module-name</name>
    <description>Description for Exchange listing</description>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <maven.compiler.source>1.8</maven.compiler.source>
        <maven.compiler.target>1.8</maven.compiler.target>
    </properties>

    <build>
        <resources>
            <resource>
                <directory>src/main/resources</directory>
            </resource>
        </resources>
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
</project>
```

### Critical Notes

| Field | Value | Notes |
|-------|-------|-------|
| `groupId` | Your Anypoint Org ID | Must be the UUID from Access Management |
| `artifactId` | Module name | e.g., `dw-string-utils` |
| `packaging` | `jar` | Standard jar packaging for DW library modules |
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
│   │       ├── module-ModuleName.xml    # Mule module descriptor
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

### Module Descriptor

Each module needs a `module-ModuleName.xml` in `src/main/resources/`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<module name="dw-module-name"
        xmlns="http://www.mulesoft.org/schema/mule/module"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        xsi:schemaLocation="http://www.mulesoft.org/schema/mule/module http://www.mulesoft.org/schema/mule/module/current/mule-module.xsd">
</module>
```

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

## Publishing

### Option A: Exchange API (Recommended)

Use the Exchange API to publish directly — no Mule runtime needed:

```bash
# 1. Get access token
TOKEN=$(curl -s -X POST https://anypoint.mulesoft.com/accounts/api/v2/oauth2/token \
  -H "Content-Type: application/json" \
  -d '{"grant_type":"client_credentials","client_id":"YOUR_CLIENT_ID","client_secret":"YOUR_CLIENT_SECRET"}' \
  | python3 -c "import json,sys;print(json.load(sys.stdin)['access_token'])")

# 2. Build the jar
mvn clean package

# 3. Publish to Exchange
curl -X POST "https://anypoint.mulesoft.com/exchange/api/v2/assets" \
  -H "Authorization: Bearer $TOKEN" \
  -F "organizationId=YOUR_ORG_ID" \
  -F "groupId=YOUR_ORG_ID" \
  -F "assetId=dw-module-name" \
  -F "version=1.0.0" \
  -F "name=dw-module-name" \
  -F "type=custom" \
  -F "classifier=custom" \
  -F "files.custom.jar=@target/dw-module-name-1.0.0.jar"
```

### Option B: Maven Deploy

```bash
mvn clean deploy
```

> Note: Maven deploy to Exchange may require the asset to be pre-created via the Exchange API first.

### Verify on Exchange

After publish, your module appears at:
```
https://anypoint.mulesoft.com/exchange/cb0ecddd-1505-4354-870f-45c4217384c2/dw-module-name/
```

---

## Exchange Metadata

When the module is published, Exchange auto-generates a listing. To enhance it:

| Metadata | Where | Notes |
|----------|-------|-------|
| Name | `pom.xml` > `<name>` | Display name on Exchange |
| Description | `pom.xml` > `<description>` | Short description shown in search |
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
| `412 Precondition Failed` | Asset must be pre-created via Exchange API before Maven deploy |
| Module not found after deploy | Wait 1-2 minutes for Exchange indexing, check org ID |
| MUnit tests fail | Ensure DW module path is exactly `src/main/resources/modules/` |
