## API Deprecation and Sunset
> Communicate version deprecation timelines and enforce sunset dates.

### When to Use
- Retiring old API versions that are no longer maintained
- Giving clients advance notice and migration time
- Enforcing hard deadlines for version removal

### Configuration / Code

```xml
<!-- Add deprecation headers to old version -->
<flow name="orders-v1-deprecated">
    <http:listener config-ref="HTTP_Listener" path="/api/v1/orders"/>
    <set-variable variableName="outboundHeaders" value="#[{
        'Deprecation': 'true',
        'Sunset': 'Sat, 01 Mar 2025 00:00:00 GMT',
        'Link': 'https://docs.example.com/migration-guide; rel=successor-version'
    }]"/>
    <flow-ref name="orders-v1-logic"/>
</flow>

<!-- Block after sunset date -->
<flow name="orders-v1-sunset">
    <http:listener config-ref="HTTP_Listener" path="/api/v1/orders"/>
    <choice>
        <when expression="#[now() > |2025-03-01T00:00:00Z|]">
            <set-payload value='{"error": "This API version has been retired"}'
                         mimeType="application/json"/>
            <http:response statusCode="410"/>
        </when>
        <otherwise>
            <flow-ref name="orders-v1-logic"/>
        </otherwise>
    </choice>
</flow>
```

### How It Works
1. `Deprecation: true` header signals the version is deprecated
2. `Sunset` header communicates the retirement date (RFC 7231)
3. `Link` header points to migration documentation
4. After the sunset date, return 410 Gone with migration instructions

### Gotchas
- Give at least 6-12 months notice for external APIs
- Monitor deprecated version traffic to identify clients who have not migrated
- 410 Gone is more appropriate than 404 for retired endpoints
- Communication through headers alone is insufficient — send emails and update docs

### Related
- [URL Path Versioning](../url-path-versioning/) — version strategy
- [Lifecycle Management](../lifecycle-management/) — full lifecycle
