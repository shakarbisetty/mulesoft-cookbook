## Document Summarizer
> Automatically summarize long documents into concise briefs.

### When to Use
- Processing lengthy contracts, reports, or articles
- Email digests of long-form content
- Knowledge base article summarization

### Configuration / Code

```xml
<flow name="document-summarizer">
    <http:listener config-ref="HTTP_Listener" path="/summarize" method="POST"/>
    <set-variable variableName="document" value="#[payload.content]"/>
    <!-- Chunk long documents -->
    <choice>
        <when expression="#[sizeOf(vars.document) > 10000]">
            <!-- Summarize in chunks, then summarize summaries -->
            <ee:transform>
                <ee:message><ee:set-payload><![CDATA[%dw 2.0
output application/json
var chunkSize = 8000
---
(0 to (sizeOf(vars.document) / chunkSize)) map
    vars.document[($ * chunkSize) to min([(($ + 1) * chunkSize) - 1, sizeOf(vars.document) - 1])]
]]></ee:set-payload></ee:message>
            </ee:transform>
            <foreach>
                <ai:chat-completions config-ref="AI_Config">
                    <ai:messages>
                        <ai:message role="system" content="Summarize this text section in 2-3 sentences."/>
                        <ai:message role="user" content="#[payload]"/>
                    </ai:messages>
                </ai:chat-completions>
            </foreach>
            <set-variable variableName="chunkSummaries" value="#[payload]"/>
            <!-- Final summary of summaries -->
            <ai:chat-completions config-ref="AI_Config">
                <ai:messages>
                    <ai:message role="system" content="Combine these section summaries into a cohesive executive summary (under 200 words)."/>
                    <ai:message role="user" content="#[vars.chunkSummaries joinBy nn]"/>
                </ai:messages>
            </ai:chat-completions>
        </when>
        <otherwise>
            <ai:chat-completions config-ref="AI_Config">
                <ai:messages>
                    <ai:message role="system" content="Provide a concise summary (under 200 words)."/>
                    <ai:message role="user" content="#[vars.document]"/>
                </ai:messages>
            </ai:chat-completions>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. Short documents are summarized directly in one LLM call
2. Long documents are chunked and each chunk is summarized
3. Chunk summaries are combined into a final executive summary
4. Map-reduce pattern handles documents of any length

### Gotchas
- Chunking may split important context — use overlap for better results
- Multi-step summarization loses detail — adjust summary length per step
- Cost scales with document length (multiple LLM calls)
- Consider extractive summarization for factual accuracy

### Related
- [Document Chunking](../../rag/document-chunking/) — chunking strategies
- [Chat Completions](../../inference/chat-completions/) — LLM calls
