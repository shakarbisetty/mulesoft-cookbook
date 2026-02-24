## Credential Vault for AI API Keys
> Securely manage and rotate AI provider API keys using secrets managers.

### When to Use
- Enterprise key management for multiple AI providers
- Automated key rotation without application downtime
- Audit trailing of AI credential usage

### Configuration / Code

```xml
<!-- Using Anypoint Secrets Manager -->
<secure-properties:config name="AI_Secrets"
    file="secure.yaml"
    key="${mule.key}">
    <secure-properties:encrypt algorithm="AES" mode="CBC"/>
</secure-properties:config>

<!-- Reference in AI connector -->
<ai:config name="AI_Config">
    <ai:openai-connection apiKey="${secure::ai.openai.key}"/>
</ai:config>

<!-- Key rotation flow (called by ops automation) -->
<flow name="rotate-ai-key">
    <http:listener config-ref="Admin_Listener" path="/admin/rotate-key" method="POST"/>
    <!-- Fetch new key from vault -->
    <http:request config-ref="Vault_Config" path="/v1/secret/data/ai-keys" method="GET"/>
    <set-variable variableName="newKey" value="#[payload.data.data.openai_key]"/>
    <!-- Update Anypoint Secrets Manager -->
    <http:request config-ref="Anypoint_API" path="/secrets/api/v1/organizations/${org.id}/environments/${env.id}/secretGroups/${sg.id}/sharedSecrets" method="PUT">
        <http:body>#[output application/json --- {name: "ai.openai.key", value: vars.newKey}]</http:body>
    </http:request>
    <!-- Trigger app restart for new key -->
    <logger message="AI API key rotated successfully"/>
</flow>
```

### How It Works
1. AI API keys are stored encrypted in Anypoint Secrets Manager
2. Mule app references keys via `${secure::}` property syntax
3. Rotation flow fetches new key from vault and updates secrets
4. App restart or dynamic reload picks up the new key

### Gotchas
- Key rotation requires coordination — old key must remain valid during transition
- Dynamic key reload avoids downtime but requires connector support
- Audit log who initiated key rotation and when
- Multiple environments need separate key management

### Related
- [Rate Limiting LLM](../rate-limiting-llm/) — usage control
- [Secrets Management](../../../devops/secrets/) — general secrets patterns
