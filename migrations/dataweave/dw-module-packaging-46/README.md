## DataWeave Module Packaging Changes in 4.6+
> Adapt DataWeave custom module packaging for Mule 4.6+ runtime compatibility

### When to Use
- Custom DataWeave modules fail to load after Mule 4.6 upgrade
- Publishing reusable DataWeave libraries to Exchange for Mule 4.6+ consumers
- DataWeave module resolution behavior changed after runtime upgrade

### Configuration / Code

#### 1. Module Project Structure (4.6+)

```
my-dw-module/
├── pom.xml
├── src/main/dw/com/mycompany/
│   ├── StringUtils.dwl
│   ├── DateUtils.dwl
│   └── Validators.dwl
├── src/main/resources/META-INF/mule-artifact/
│   └── mule-artifact.json
└── mule-artifact.json
```

#### 2. POM Configuration

```xml
<project>
    <modelVersion>4.0.0</modelVersion>
    <groupId>com.mycompany</groupId>
    <artifactId>dw-common-utils</artifactId>
    <version>1.0.0</version>
    <packaging>mule-plugin</packaging>
    <parent>
        <groupId>org.mule.extensions</groupId>
        <artifactId>mule-modules-parent</artifactId>
        <version>1.6.0</version>
    </parent>
    <properties>
        <mule.version>4.6.0</mule.version>
    </properties>
    <build>
        <plugins>
            <plugin>
                <groupId>org.mule.tools.maven</groupId>
                <artifactId>mule-maven-plugin</artifactId>
                <version>4.1.1</version>
                <extensions>true</extensions>
            </plugin>
        </plugins>
    </build>
</project>
```

#### 3. mule-artifact.json (Updated for 4.6+)

```json
{
    "minMuleVersion": "4.6.0",
    "classLoaderModelLoaderDescriptor": {
        "id": "mule",
        "attributes": {
            "exportedResources": [
                "dw/com/mycompany/StringUtils.dwl",
                "dw/com/mycompany/DateUtils.dwl",
                "dw/com/mycompany/Validators.dwl"
            ],
            "exportedPackages": []
        }
    }
}
```

#### 4. DataWeave Module File

```dataweave
// src/main/dw/com/mycompany/StringUtils.dwl
%dw 2.0
fun capitalize(text: String): String =
    upper(text[0]) ++ lower(text[1 to -1])
fun slugify(text: String): String =
    lower(text) replace /[^a-z0-9]+/ with "-" replace /^-|-$/ with ""
fun truncate(text: String, maxLength: Number): String =
    if (sizeOf(text) <= maxLength) text
    else text[0 to maxLength - 4] ++ "..."
```

#### 5. Consumer Usage

```xml
<dependency>
    <groupId>com.mycompany</groupId>
    <artifactId>dw-common-utils</artifactId>
    <version>1.0.0</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

```dataweave
%dw 2.0
import * from com::mycompany::StringUtils
output application/json
---
{ title: capitalize(payload.name), slug: slugify(payload.title) }
```

### How It Works
1. Mule 4.6+ tightened module resolution — `exportedResources` must explicitly list DWL files
2. DWL file path under `src/main/dw/` determines the import path (using `::` separator)
3. Modules are packaged as Mule plugins and published to Exchange or Maven repo
4. Consumer apps add the module as a `mule-plugin` classified dependency

### Migration Checklist
- [ ] Update `mule-artifact.json` to list all DWL files in `exportedResources`
- [ ] Set `minMuleVersion` to `4.6.0` or higher
- [ ] Update parent POM to `mule-modules-parent` 1.6.0+
- [ ] Rebuild and republish module to Exchange
- [ ] Test module import in consumer apps on Mule 4.6+

### Gotchas
- Missing or empty `exportedResources` makes DWL files invisible on 4.6+
- File paths in `exportedResources` must match directory structure exactly
- Mule 4.4 was more lenient — code that worked before may break on 4.6
- DataWeave modules cannot import Java classes directly — use the Java module bridge

### Related
- [mule44-to-46](../../runtime-upgrades/mule44-to-46/) — Runtime upgrade context
- [fragment-library-migration](../../api-specs/fragment-library-migration/) — Exchange library patterns
