## Data Enrichment Agent
> Use AI to enrich records with inferred or generated data fields.

### When to Use
- Enriching CRM records with company descriptions or industry classification
- Generating product descriptions from specifications
- Inferring missing data fields from available context

### Configuration / Code

```xml
<flow name="enrich-company-records">
    <scheduler><scheduling-strategy><fixed-frequency frequency="86400000"/></scheduling-strategy></scheduler>
    <db:select config-ref="Database_Config">
        <db:sql>SELECT id, company_name, website FROM companies WHERE description IS NULL LIMIT 50</db:sql>
    </db:select>
    <foreach>
        <ai:chat-completions config-ref="AI_Config">
            <ai:messages>
                <ai:message role="system" content="Generate a brief company description (2-3 sentences) and classify the industry. Return JSON: {description, industry, employeeRange}"/>
                <ai:message role="user" content="#[Company:
