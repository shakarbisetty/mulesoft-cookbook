## Image Generation via AI APIs
> Generate images from text prompts using DALL-E or Stable Diffusion APIs.

### When to Use
- Auto-generating product images from descriptions
- Creating visual content for marketing workflows
- Generating diagrams or charts from data

### Configuration / Code

```xml
<flow name="generate-image">
    <http:listener config-ref="HTTP_Listener" path="/generate-image" method="POST"/>
    <http:request config-ref="OpenAI_Config" path="/v1/images/generations" method="POST">
        <http:body>#[output application/json --- {
            model: "dall-e-3",
            prompt: payload.prompt,
            n: 1,
            size: "1024x1024",
            quality: "standard"
        }]</http:body>
    </http:request>
    <set-payload value="#[output application/json --- {
        imageUrl: payload.data[0].url,
        revisedPrompt: payload.data[0].revised_prompt
    }]"/>
</flow>
```

### How It Works
1. Text prompt describes the desired image
2. API generates the image and returns a URL or base64 data
3. `revised_prompt` shows how the model interpreted your prompt
4. Images are temporarily hosted — download and store permanently

### Gotchas
- Generated image URLs expire (typically 1 hour) — save to persistent storage
- Image generation is slow (5-30s) — use async processing for batch operations
- Content policy may reject certain prompts — handle 400 errors gracefully
- Cost per image is higher than text generation — implement usage controls

### Related
- [Chat Completions](../chat-completions/) — text generation
- [Token Usage Tracking](../../ai-gateway/token-usage-tracking/) — cost monitoring
