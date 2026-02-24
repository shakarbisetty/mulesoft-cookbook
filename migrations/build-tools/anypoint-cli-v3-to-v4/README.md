## Anypoint CLI v3 to v4 Command Migration
> Migrate Anypoint CLI commands from v3 to v4 syntax

### When to Use
- CLI v3 end-of-life or deprecation
- Updating automation scripts and CI/CD pipelines
- Need CloudHub 2.0 CLI support (v4 only)

### Configuration / Code

#### 1. Install CLI v4

```bash
# Install via npm
npm install -g anypoint-cli-v4

# Or download binary
curl -L -o anypoint-cli https://downloads.anypoint.mulesoft.com/cli/v4/anypoint-cli-v4
chmod +x anypoint-cli
```

#### 2. Authentication Changes

```bash
# v3: username/password
anypoint-cli --username=admin --password=secret

# v4: Connected App (recommended)
anypoint-cli-v4 account login \
    --client-id "${AP_CLIENT_ID}" \
    --client-secret "${AP_CLIENT_SECRET}"

# v4: bearer token
anypoint-cli-v4 account login --bearer "${TOKEN}"
```

#### 3. Command Mapping

| CLI v3 | CLI v4 |
|---|---|
| `runtime-mgr cloudhub-application list` | `runtime-mgr app list` |
| `runtime-mgr cloudhub-application describe` | `runtime-mgr app describe` |
| `runtime-mgr cloudhub-application deploy` | `runtime-mgr app deploy` |
| `runtime-mgr cloudhub-application modify` | `runtime-mgr app modify` |
| `runtime-mgr cloudhub-application delete` | `runtime-mgr app delete` |
| `api-mgr api list` | `api-mgr api list` |
| `exchange asset upload` | `exchange asset upload` |
| `designcenter project list` | `designcenter project list` |

#### 4. Output Format Changes

```bash
# v3: table output
anypoint-cli runtime-mgr cloudhub-application list

# v4: JSON output (default), table optional
anypoint-cli-v4 runtime-mgr app list --output json
anypoint-cli-v4 runtime-mgr app list --output table
```

#### 5. CI/CD Script Update

```bash
#!/bin/bash
# Before (v3)
anypoint-cli \
    --username="${AP_USER}" \
    --password="${AP_PASS}" \
    --environment=Production \
    runtime-mgr cloudhub-application deploy \
    my-api target/my-api.jar \
    --runtime="4.4.0" \
    --workers=2 \
    --workerSize=0.2

# After (v4)
anypoint-cli-v4 account login \
    --client-id "${AP_CLIENT_ID}" \
    --client-secret "${AP_CLIENT_SECRET}"

anypoint-cli-v4 runtime-mgr app deploy \
    --name "my-api" \
    --target "Shared Space" \
    --runtime-version "4.6.0" \
    --replicas 2 \
    --vcores 0.5 \
    --artifact ./target/my-api.jar \
    --environment "Production"
```

### How It Works
1. CLI v4 is a complete rewrite with updated command structure
2. Authentication shifted to Connected Apps (OAuth 2.0)
3. Default output is JSON for better scripting support
4. CloudHub 2.0 commands are only available in v4

### Migration Checklist
- [ ] Install CLI v4 alongside v3 (different binary names)
- [ ] Create Connected App for CLI authentication
- [ ] Map all v3 commands to v4 equivalents
- [ ] Update CI/CD scripts
- [ ] Test all automated operations
- [ ] Remove CLI v3 after verification

### Gotchas
- CLI v4 binary is `anypoint-cli-v4`, not `anypoint-cli`
- Some v3 flags changed names in v4
- JSON output format may break scripts expecting table format
- Connected App needs specific scopes for each operation

### Related
- [cicd-for-ch2](../cicd-for-ch2/) - CI/CD updates
- [platform-permissions](../../security/platform-permissions/) - Connected Apps
