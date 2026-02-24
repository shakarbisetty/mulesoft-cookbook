## Model Fallback Chain
> Automatically fall back to alternative models when the primary model is unavailable.

### When to Use
- High-availability AI applications requiring 99.9%+ uptime
- Handling provider outages or rate limit exhaustion
- Cost optimization by trying cheaper models first

### Configuration / Code

```xml
<flow name="model-fallback">
    <http:listener config-ref="HTTP_Listener" path="/chat" method="POST"/>
    <try>
        <!-- Try primary model -->
        <http:request config-ref="OpenAI_Config" path="/v1/chat/completions" method="POST"
                      responseTimeout="10000">
            <http:body>#[output application/json --- payload ++ {model: "gpt-4o"}]</http:body>
        </http:request>
        <error-handler>
            <on-error-continue type="HTTP:TIMEOUT, HTTP:SERVICE_UNAVAILABLE, HTTP:TOO_MANY_REQUESTS">
                <try>
                    <!-- Fallback to secondary -->
                    <http:request config-ref="Azure_OpenAI_Config" path="/openai/deployments/gpt-4o/chat/completions"
                                  method="POST" responseTimeout="15000"/>
                    <error-handler>
                        <on-error-continue>
                            <!-- Last resort: cheaper model -->
                            <http:request config-ref="OpenAI_Config" path="/v1/chat/completions" method="POST">
                                <http:body>#[output application/json --- payload ++ {model: "gpt-4o-mini"}]</http:body>
                            </http:request>
                        </on-error-continue>
                    </error-handler>
                </try>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. Primary model (GPT-4o) is tried first with a strict timeout
2. On timeout, 503, or 429, the flow falls back to Azure OpenAI
3. If Azure also fails, a cheaper model (GPT-4o-mini) is the last resort
4. Client receives a response from whichever model succeeds

### Gotchas
- Different models produce different quality responses — document the trade-off
- Fallback adds cumulative latency — set tight timeouts on primary
- Log which model actually served the request for quality monitoring
- Fallback chain should be tested regularly to verify all paths work

### Related
- [Flex AI Proxy](../flex-ai-proxy/) — gateway routing
- [Token Usage Tracking](../token-usage-tracking/) — per-model cost tracking
