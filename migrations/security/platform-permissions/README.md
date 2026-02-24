## Legacy Roles to Connected Apps + Teams
> Migrate from legacy Anypoint Platform roles to Connected Apps and Teams model

### When to Use
- Anypoint Platform deprecating legacy role-based access
- Need machine-to-machine authentication (Connected Apps)
- Implementing team-based access control
- CI/CD pipelines using username/password authentication

### Configuration / Code

#### 1. Create Connected App (CI/CD)

```bash
# Create Connected App for CI/CD
# Via Anypoint Platform > Access Management > Connected Apps

# Grant scopes:
# - Design Center Developer
# - Exchange Contributor
# - Runtime Manager - Manage Applications
# - API Manager - Manage APIs
```

#### 2. Use Connected App in Maven

```xml
<plugin>
    <groupId>org.mule.tools.maven</groupId>
    <artifactId>mule-maven-plugin</artifactId>
    <configuration>
        <cloudhub2Deployment>
            <connectedAppClientId>${AP_CLIENT_ID}</connectedAppClientId>
            <connectedAppClientSecret>${AP_CLIENT_SECRET}</connectedAppClientSecret>
            <connectedAppGrantType>client_credentials</connectedAppGrantType>
        </cloudhub2Deployment>
    </configuration>
</plugin>
```

#### 3. Use Connected App in CLI

```bash
# Authenticate with Connected App
anypoint-cli-v4 account login \
    --client-id "${AP_CLIENT_ID}" \
    --client-secret "${AP_CLIENT_SECRET}"
```

#### 4. Create Team Structure

```
Organization
  Platform Team (full admin)
  API Team
    API Designers (Design Center, Exchange)
    API Developers (Runtime Manager, deploy)
    API Operators (monitoring, alerts)
  Integration Team
    Mule Developers (Studio, deploy to dev/staging)
    Release Managers (deploy to production)
```

#### 5. Team Permission Mapping

| Legacy Role | Team + Permission |
|---|---|
| Organization Admin | Platform Team - Organization Admin |
| API Creator | API Designers - Design Center Developer |
| Deployer | Release Managers - CloudHub Admin |
| Viewer | API Operators - Read-only |
| Exchange Contributor | API Designers - Exchange Contributor |

### How It Works
1. Connected Apps replace username/password for automation
2. Teams replace individual role assignments for human users
3. Connected Apps use OAuth 2.0 client_credentials flow
4. Teams can inherit permissions from parent teams

### Migration Checklist
- [ ] Inventory all users and their current roles
- [ ] Design team structure matching organizational needs
- [ ] Create Connected Apps for all CI/CD pipelines
- [ ] Create teams and assign permissions
- [ ] Move users to appropriate teams
- [ ] Update CI/CD to use Connected App credentials
- [ ] Remove legacy username/password from pipelines
- [ ] Remove legacy role assignments
- [ ] Document team permission matrix

### Gotchas
- Connected App scopes are more granular than legacy roles
- Some legacy permissions do not map 1:1 to new scopes
- Users can belong to multiple teams
- Connected Apps have separate rate limits from user sessions
- Team deletions do not automatically reassign members

### Related
- [cicd-for-ch2](../../build-tools/cicd-for-ch2/) - CI/CD updates
- [credentials-to-secure-props](../credentials-to-secure-props/) - Credential management
