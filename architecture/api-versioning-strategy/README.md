## API Versioning Strategy
> URI vs header vs media-type versioning with migration patterns for MuleSoft APIs

### When to Use
- You are publishing APIs to external consumers and need to evolve without breaking them
- Your API contract is changing (fields removed, renamed, or restructured)
- You need to run multiple API versions simultaneously during a migration period
- You want a consistent versioning standard across your MuleSoft API catalog

### The Problem

APIs change. Fields get renamed, endpoints restructured, and data models evolve. Without a versioning strategy, any change risks breaking existing consumers. The challenge is not just choosing a versioning scheme — it is managing the lifecycle of multiple versions running simultaneously, migrating consumers, and eventually sunsetting old versions without operational chaos.

MuleSoft supports all major versioning approaches through APIkit, API Manager policies, and routing logic. The decision depends on your consumer ecosystem, governance maturity, and operational capacity.

### Configuration / Code

#### Versioning Approaches Comparison

| Approach | Example | Pros | Cons |
|----------|---------|------|------|
| **URI path** | `/v1/orders`, `/v2/orders` | Visible, cacheable, simple routing | URL pollution, hard to sunset |
| **Query parameter** | `/orders?version=2` | Easy to implement | Not RESTful, cache issues |
| **Custom header** | `X-API-Version: 2` | Clean URLs, flexible | Invisible, harder to test |
| **Accept header (media type)** | `Accept: application/vnd.company.v2+json` | RESTful, content negotiation | Complex, poor tooling support |
| **API Manager policy** | SLA tier maps to version | No code changes | Limited flexibility |

#### Recommended: URI Path Versioning

URI path versioning is the most practical choice for MuleSoft APIs. It is explicit, easy to route, cacheable, and works well with API Manager analytics (separate API instances per version).

```
API Catalog:
  ┌─────────────────────────────────────────────────┐
  │  Orders API v1  ──►  /api/v1/orders             │
  │  Orders API v2  ──►  /api/v2/orders             │
  │                                                  │
  │  v1: Stable, maintenance-only, sunset in 6 months│
  │  v2: Active development, all new features        │
  └─────────────────────────────────────────────────┘
```

#### Single Application, Multi-Version Router

```xml
<!-- Version router — single application serves both versions -->
<flow name="orders-api-router">
    <http:listener config-ref="HTTPS_Listener" path="/api/{version}/orders/*" />

    <choice>
        <when expression="#[attributes.uriParams.version == 'v1']">
            <flow-ref name="orders-v1-router" />
        </when>
        <when expression="#[attributes.uriParams.version == 'v2']">
            <flow-ref name="orders-v2-router" />
        </when>
        <otherwise>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "Unsupported API version",
    supportedVersions: ["v1", "v2"],
    latestVersion: "v2"
}]]></ee:set-payload>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 400 }]]></ee:set-attributes>
                </ee:message>
            </ee:transform>
        </otherwise>
    </choice>
</flow>

<!-- V1 implementation -->
<sub-flow name="orders-v1-router">
    <apikit:router config-ref="orders-v1-api-config" />
</sub-flow>

<!-- V2 implementation -->
<sub-flow name="orders-v2-router">
    <apikit:router config-ref="orders-v2-api-config" />
</sub-flow>
```

#### Separate Applications per Version

```
Deployment topology (recommended for major versions):

  API Manager
    ├── Orders API v1 (api-orders-v1) ──► CloudHub app: orders-v1
    │     ├── Client-ID policies
    │     ├── Rate limit: 100 req/min (throttled, sunset mode)
    │     └── Analytics: track remaining v1 consumers
    │
    └── Orders API v2 (api-orders-v2) ──► CloudHub app: orders-v2
          ├── Client-ID policies
          ├── Rate limit: 1000 req/min (full capacity)
          └── Analytics: track adoption

  DLB routes:
    api.company.com/v1/orders ──► orders-v1.cloudhub.io
    api.company.com/v2/orders ──► orders-v2.cloudhub.io
```

#### Version Transformation Layer

When v2 changes the data model but both versions share the same backend:

```xml
<!-- V1 and V2 share the same backend but expose different contracts -->
<sub-flow name="get-orders-v1">
    <!-- Call shared backend -->
    <flow-ref name="get-orders-from-backend" />

    <!-- Transform to v1 contract -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map {
    // v1 uses flat structure
    orderId: $.id,
    customerName: $.customer.firstName ++ " " ++ $.customer.lastName,
    orderTotal: $.pricing.total,
    orderDate: $.createdAt as String { format: "MM/dd/yyyy" },
    // v1 has "items" as a count, not the full array
    itemCount: sizeOf($.lineItems)
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>

<sub-flow name="get-orders-v2">
    <!-- Call same backend -->
    <flow-ref name="get-orders-from-backend" />

    <!-- Transform to v2 contract (richer, nested) -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload map {
    // v2 uses nested structure with more detail
    id: $.id,
    customer: {
        id: $.customer.id,
        firstName: $.customer.firstName,
        lastName: $.customer.lastName,
        email: $.customer.email
    },
    pricing: {
        subtotal: $.pricing.subtotal,
        tax: $.pricing.tax,
        discount: $.pricing.discount,
        total: $.pricing.total,
        currency: $.pricing.currency default "USD"
    },
    lineItems: $.lineItems map {
        sku: $.sku,
        name: $.productName,
        quantity: $.quantity,
        unitPrice: $.unitPrice
    },
    metadata: {
        createdAt: $.createdAt,
        updatedAt: $.updatedAt,
        version: $.version
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</sub-flow>
```

#### Deprecation Header Pattern

```xml
<!-- Add deprecation headers to v1 responses -->
<sub-flow name="add-v1-deprecation-headers">
    <ee:transform>
        <ee:message>
            <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
attributes ++ {
    headers: {
        "Deprecation": "true",
        "Sunset": "2026-09-01T00:00:00Z",
        "Link": '</api/v2/orders>; rel="successor-version"',
        "X-API-Warn": "v1 will be removed on 2026-09-01. Migrate to v2."
    }
}]]></ee:set-attributes>
        </ee:message>
    </ee:transform>
</sub-flow>
```

#### Version Lifecycle

```
     ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐
     │  ALPHA   │────►│   BETA   │────►│ CURRENT  │────►│DEPRECATED│────► SUNSET
     │ /v3-alpha│     │ /v3-beta │     │   /v3    │     │  /v2     │     (removed)
     └──────────┘     └──────────┘     └──────────┘     └──────────┘

  Duration guidelines:
  - Alpha: 1-3 months (internal testing only)
  - Beta: 1-3 months (select consumers, breaking changes OK)
  - Current: 12-24 months (stable, no breaking changes)
  - Deprecated: 6-12 months (sunset notice, reduced rate limits)
  - Sunset: version removed, 410 Gone returned
```

#### Breaking vs Non-Breaking Changes

| Change Type | Breaking? | Versioning Required? |
|-------------|-----------|---------------------|
| Add optional field to response | No | No |
| Add optional query parameter | No | No |
| Add new endpoint | No | No |
| Remove field from response | Yes | Yes — new major version |
| Rename field | Yes | Yes — new major version |
| Change field type | Yes | Yes — new major version |
| Remove endpoint | Yes | Yes — new major version |
| Change error format | Yes | Yes — new major version |
| Add required field to request | Yes | Yes — new major version |
| Tighten validation | Potentially | Evaluate — may need version |

### How It Works

1. **Start with v1** — do not pre-version. Version only when you need a breaking change.
2. **Non-breaking changes go into the current version** — additive changes never require a new version.
3. **Breaking changes create a new major version** — v1 to v2. Deploy alongside v1.
4. **Add deprecation headers to the old version** — `Deprecation: true`, `Sunset` date, link to new version.
5. **Monitor v1 usage via API Manager analytics** — track which clients still use v1.
6. **Communicate sunset timeline** — 6-12 months notice minimum for external APIs.
7. **Sunset the old version** — return 410 Gone with migration instructions.

### Gotchas

- **Do not version prematurely.** Adding `/v1/` from the start is fine for external APIs, but do not create `/v2/` until you have an actual breaking change. Phantom versions confuse consumers.
- **Shared backend changes affect all versions.** If you change a database schema that v1 and v2 both use, you must update both version transformation layers. Test both versions on every backend change.
- **API Manager treats each version as a separate API instance.** This is actually helpful — you get separate analytics, policies, and SLA tiers per version. But it doubles your API management overhead.
- **RAML/OAS spec per version.** Each version needs its own API specification. Store them separately and keep them in sync with the implementation.
- **Consumer migration is a project, not an announcement.** Budget dedicated effort for consumer outreach, testing support, and migration assistance. A deprecation header alone does not migrate consumers.

### Related

- [API-Led Layer Decision Framework](../api-led-layer-decision-framework/) — version strategy affects layer design
- [Anti-Corruption Layer](../anti-corruption-layer/) — version translation as an ACL
- [Strangler Fig Migration](../strangler-fig-migration/) — versioning during legacy replacement
- [Rate Limiting Architecture](../rate-limiting-architecture/) — per-version rate limits for sunset management
