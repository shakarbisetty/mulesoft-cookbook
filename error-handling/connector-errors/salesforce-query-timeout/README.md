## Salesforce Query Timeout
> Handle SFDC:QUERY_TIMEOUT for large SOQL queries by switching to bulk API or narrowing the query.

### When to Use
- Large SOQL queries exceed the Salesforce 120-second timeout
- You need to gracefully degrade to bulk API for large result sets
- Query optimization hints for the caller

### Configuration / Code

```xml
<flow name="sfdc-bulk-fallback-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/contacts"/>
    <try>
        <salesforce:query config-ref="Salesforce_Config">
            <salesforce:salesforce-query>
                SELECT Id, Name, Email FROM Contact WHERE LastModifiedDate > :lastSync
            </salesforce:salesforce-query>
        </salesforce:query>
        <error-handler>
            <on-error-continue type="SFDC:QUERY_TIMEOUT">
                <logger level="WARN" message="SOQL query timed out, switching to Bulk API"/>
                <salesforce:create-job config-ref="Salesforce_Config" operation="query" object="Contact">
                    <salesforce:query>SELECT Id, Name, Email FROM Contact WHERE LastModifiedDate > #[vars.lastSync]</salesforce:query>
                </salesforce:create-job>
                <set-payload value='#[output application/json --- {status: "bulk_job_created", jobId: payload.id}]' mimeType="application/json"/>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### How It Works
1. Try the standard SOQL query first (faster for small result sets)
2. On `SFDC:QUERY_TIMEOUT`, fall back to Salesforce Bulk API
3. Bulk API creates an async job that processes in the background
4. Return the job ID so the client can poll for results

### Gotchas
- Bulk API queries are async — the client needs a separate polling endpoint
- `SFDC:QUERY_TIMEOUT` vs `SFDC:CONNECTIVITY` — timeout is about query execution, connectivity is about network
- Add `LIMIT` and `WHERE` clauses to prevent unnecessary large queries
- Salesforce governor limits still apply in Bulk API

### Related
- [Salesforce Invalid Session](../salesforce-invalid-session/) — session recovery
- [DB Cursor Streaming](../../performance/streaming/db-cursor-streaming/) — streaming large result sets
