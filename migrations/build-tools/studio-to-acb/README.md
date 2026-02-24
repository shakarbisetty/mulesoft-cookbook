## Anypoint Studio to Anypoint Code Builder
> Migrate development workflow from Anypoint Studio (Eclipse) to Anypoint Code Builder (VS Code)

### When to Use
- Adopting VS Code as primary IDE
- Need cloud-based development environment
- Studio performance issues on local machine
- Team standardizing on VS Code extensions

### Configuration / Code

#### 1. Install Anypoint Code Builder

```bash
# Install VS Code extension
code --install-extension MuleSoft.anypoint-code-builder

# Or install from VS Code Marketplace:
# Search "Anypoint Code Builder" in Extensions
```

#### 2. Project Import

```bash
# ACB works with standard Mule Maven projects
# Open existing project folder in VS Code
code /path/to/mule-project

# Or create new project via command palette:
# Ctrl+Shift+P > "MuleSoft: Create Mule Application"
```

#### 3. Feature Mapping

| Studio Feature | ACB Equivalent |
|---|---|
| Visual Flow Designer | Flow Designer (canvas view) |
| DataWeave Editor | DataWeave preview pane |
| MUnit Test Runner | MUnit integration (run from editor) |
| API Sync with Design Center | API sync built-in |
| Maven Build | Terminal + Maven commands |
| Debugger | Mule Debugger extension |
| Exchange Search | Exchange panel in sidebar |
| Metadata Resolution | Auto-resolution from connectors |

#### 4. Key Configuration Files

```json
// .vscode/settings.json
{
    "mule.runtime.version": "4.6.0",
    "mule.java.home": "/usr/lib/jvm/temurin-17-jdk",
    "mule.maven.settings": "~/.m2/settings.xml",
    "editor.formatOnSave": true,
    "xml.format.enabled": true
}
```

#### 5. Maven Settings for Exchange

```xml
<!-- ~/.m2/settings.xml -->
<settings>
    <servers>
        <server>
            <id>anypoint-exchange-v3</id>
            <username>~~~Client~~~</username>
            <password>${AP_CLIENT_ID}~?~${AP_CLIENT_SECRET}</password>
        </server>
    </servers>
    <profiles>
        <profile>
            <id>mulesoft</id>
            <repositories>
                <repository>
                    <id>anypoint-exchange-v3</id>
                    <url>https://maven.anypoint.mulesoft.com/api/v3/maven</url>
                </repository>
            </repositories>
        </profile>
    </profiles>
    <activeProfiles>
        <activeProfile>mulesoft</activeProfile>
    </activeProfiles>
</settings>
```

### How It Works
1. ACB is a VS Code extension providing Mule development features
2. Projects use the same Maven structure as Studio projects
3. Flow editing available in both visual (canvas) and XML modes
4. Cloud-based option runs in browser via Anypoint Platform

### Migration Checklist
- [ ] Install VS Code and Anypoint Code Builder extension
- [ ] Configure Maven settings with Exchange credentials
- [ ] Set Java home path in VS Code settings
- [ ] Open existing Studio project in ACB
- [ ] Verify flow rendering in canvas view
- [ ] Test DataWeave editing and preview
- [ ] Run MUnit tests from ACB
- [ ] Test deployment from terminal
- [ ] Verify debugger works

### Gotchas
- ACB is newer and may lack some Studio features
- Studio `.mflow` visual metadata may not transfer
- Some Enterprise connectors may not have ACB metadata yet
- DataSense/metadata resolution may behave differently
- Team must align on consistent VS Code extension versions

### Related
- [design-center-to-code-first](../../api-specs/design-center-to-code-first/) - Code-first workflow
- [cicd-for-ch2](../cicd-for-ch2/) - CI/CD pipeline
