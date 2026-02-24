## Rate Limiting for LLM APIs
> Apply per-team and per-model rate limits to control AI costs.

### When to Use
- Preventing runaway AI costs from uncontrolled usage
- Fair usage enforcement across teams
- Budget allocation for different AI models

### Configuration / Code

```xml
<flow name="rate-limited-ai">
    <http:listener config-ref="HTTP_Listener" path="/ai/chat" method="POST"/>
    <set-variable variableName="teamId" value="#[attributes.headers.x-team-id]"/>
    <!-- Check rate limit -->
    <os:retrieve key="#[vars.teamId ++ -count]" objectStore="rate-limit-store" target="count">
        <os:default-value>#[0]</os:default-value>
    </os:retrieve>
    <choice>
        <when expression="#[vars.count >= 1000]">
            <set-payload value={error:
