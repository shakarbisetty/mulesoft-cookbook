## Data Enrichment Agent
> Use AI to enrich records with inferred or generated data fields.

### When to Use
- Enriching CRM records with company descriptions or industry classification
- Generating product descriptions from specifications
- Inferring missing data fields from available context

### Configuration / Code

```xml
<flow name="enrich-company-records">
    <scheduler>
        <scheduling-strategy><fixed-frequency frequency="86400000"/></scheduling-strategy>
    </scheduler>
    <db:select config-ref="Database_Config">
        <db:sql>SELECT id, company_name, website FROM companies WHERE description IS NULL LIMIT 50</db:sql>
    </db:select>
    <foreach>
        <ai:chat-completions config-ref="AI_Config">
            <ai:messages>
                <ai:message role="system" content="Generate a brief company description (2-3 sentences) and classify the industry. Return JSON: {description, industry, employeeRange}"/>
                <ai:message role="user" content="#['Company: ' ++ payload.company_name ++ ', Website: ' ++ (payload.website default 'unknown')]"/>
            </ai:messages>
            <ai:config temperature="0.3" maxTokens="200"/>
        </ai:chat-completions>
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
var aiResult = read(payload.choices[0].message.content, "application/json")
---
{
    id: vars.rootMessage.payload.id,
    description: aiResult.description,
    industry: aiResult.industry,
    employeeRange: aiResult.employeeRange
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        <db:update config-ref="Database_Config">
            <db:sql>UPDATE companies SET description = :description, industry = :industry, employee_range = :employeeRange WHERE id = :id</db:sql>
            <db:input-parameters>#[{
                id: payload.id,
                description: payload.description,
                industry: payload.industry,
                employeeRange: payload.employeeRange
            }]</db:input-parameters>
        </db:update>
    </foreach>
    <logger message="#['Enriched ' ++ sizeOf(payload) ++ ' company records']" level="INFO"/>
</flow>
```

### How It Works
1. A daily scheduler triggers the enrichment batch (every 86,400,000ms = 24 hours)
2. Database query selects up to 50 companies with missing descriptions
3. For each record, the AI connector generates a description and classifies the industry
4. Low temperature (0.3) ensures consistent, factual responses
5. The AI response is parsed from JSON string into a DataWeave object
6. Database UPDATE writes the enriched fields back to the source record
7. Logger reports how many records were enriched in the batch

### Gotchas
- Limit batch size (50) to control API costs — at $0.01/call, 50 records = $0.50/day
- Set `temperature: 0.3` for factual enrichment — higher values produce creative/inconsistent results
- Validate AI JSON output — wrap in try/catch for malformed responses
- Add a `last_enriched` timestamp to avoid re-enriching records on failures
- Consider caching enrichment results for companies that appear in multiple records

### Related
- [Email Classifier](../email-classifier/) — similar AI-powered classification pattern
- [Document Summarizer](../document-summarizer/) — AI enrichment for document content
- [Sentiment Analysis](../sentiment-analysis/) — enriching records with sentiment scores
