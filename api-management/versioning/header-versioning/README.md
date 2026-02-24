## Header-Based API Versioning
> Version APIs using custom headers or Accept header content negotiation.

### When to Use
- Clean URLs without version numbers
- Gradual rollout where default version can change
- API consumers who can set custom headers

### Configuration / Code

```xml
<flow name="orders-api">
    <http:listener config-ref="HTTP_Listener" path="/api/orders"/>
    <choice>
        <when expression="#[attributes.headers.api-version == 2]">
            <flow-ref name="orders-v2-logic"/>
        </when>
        <otherwise>
            <!-- Default to v1 -->
            <flow-ref name="orders-v1-logic"/>
        </otherwise>
    </choice>
</flow>
```

**Accept header approach:**
```
GET /api/orders
Accept: application/vnd.example.v2+json
```

### How It Works
1. Client specifies version in a custom header (`API-Version: 2`) or Accept header
2. Single endpoint routes internally based on the header value
3. Missing header defaults to the latest stable version
4. Response includes the version used (`X-API-Version: 2`)

### Gotchas
- Harder to test — cannot simply change the URL in a browser
- API documentation must clearly show required headers
- Caching is affected — `Vary: API-Version` header is required
- Load balancers and CDNs may not inspect custom headers for routing

### Related
- [URL Path Versioning](../url-path-versioning/) — URL-based versioning
- [Content Negotiation](../../../performance/api-performance/content-negotiation/) — response format control
