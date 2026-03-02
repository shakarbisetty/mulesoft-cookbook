## Data Mesh Integration
> MuleSoft as data product APIs with domain-owned data serving

### When to Use
- Your organization is moving from centralized data lakes to domain-owned data products
- Integration teams are bottlenecked because every data request routes through a central team
- You want to treat APIs as data products with SLAs, discoverability, and self-serve consumption
- Domain teams need to own and serve their data without depending on a central integration team

### The Problem

Centralized integration teams become bottlenecks. Every data request — from analytics, machine learning, partner APIs, or internal tools — funnels through the same team. The backlog grows, delivery slows, and domains lose ownership of their data quality and timeliness.

Data mesh shifts ownership to domain teams: each domain owns its data, serves it as a product, and is accountable for its quality. MuleSoft provides the infrastructure to expose domain data as discoverable, governed, self-serve APIs — the "data product APIs" in mesh terminology.

### Configuration / Code

#### Data Mesh Architecture with MuleSoft

```
┌─────────────────────────────────────────────────────────────────┐
│                   SELF-SERVE DATA PLATFORM                      │
│                                                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────┐  │
│  │ Anypoint Exchange │  │  API Manager     │  │ Anypoint     │  │
│  │ (Discovery)       │  │  (Governance)    │  │ Monitoring   │  │
│  │                    │  │                  │  │ (SLA)        │  │
│  │ - API catalog      │  │  - Policies      │  │ - Latency    │  │
│  │ - Schemas          │  │  - Rate limits   │  │ - Errors     │  │
│  │ - Documentation    │  │  - Access control│  │ - Throughput │  │
│  └────────────────────┘  └──────────────────┘  └──────────────┘  │
└──────────┬──────────────────────┬───────────────────┬────────────┘
           │                      │                   │
  ┌────────▼────────┐   ┌────────▼────────┐  ┌───────▼────────┐
  │  ORDERS DOMAIN  │   │ CUSTOMER DOMAIN │  │ PRODUCT DOMAIN │
  │                 │   │                 │  │                │
  │ ┌─────────────┐ │   │ ┌─────────────┐ │  │ ┌────────────┐ │
  │ │ Order Data  │ │   │ │ Customer    │ │  │ │ Product    │ │
  │ │ Product API │ │   │ │ Data Product│ │  │ │ Data       │ │
  │ │             │ │   │ │ API         │ │  │ │ Product API│ │
  │ │ - REST API  │ │   │ │             │ │  │ │            │ │
  │ │ - Events    │ │   │ │ - REST API  │ │  │ │ - REST API │ │
  │ │ - Batch     │ │   │ │ - CDC events│ │  │ │ - GraphQL  │ │
  │ └──────┬──────┘ │   │ └──────┬──────┘ │  │ └──────┬─────┘ │
  │        │        │   │        │        │  │        │       │
  │ ┌──────▼──────┐ │   │ ┌──────▼──────┐ │  │ ┌──────▼─────┐ │
  │ │ Orders DB   │ │   │ │ CRM / SFDC  │ │  │ │ PIM / SAP  │ │
  │ │ (owned)     │ │   │ │ (owned)     │ │  │ │ (owned)    │ │
  │ └─────────────┘ │   │ └─────────────┘ │  │ └────────────┘ │
  └─────────────────┘   └─────────────────┘  └────────────────┘

  Each domain:
  - OWNS its data source
  - PUBLISHES its data product API
  - DEFINES its SLA and access policies
  - IS ACCOUNTABLE for data quality
```

#### Data Product API Structure

Each domain's data product API follows a standard template:

```
data-product-api/
├── src/main/
│   ├── mule/
│   │   ├── data-product-orders.xml        ← API implementation
│   │   ├── data-quality-checks.xml        ← Quality validation
│   │   └── data-product-events.xml        ← CDC/event publishing
│   └── resources/
│       ├── api/
│       │   └── data-product-orders.raml   ← API contract
│       └── metadata/
│           ├── data-product-manifest.json ← Product metadata
│           └── schema.json                ← Data schema
└── pom.xml
```

#### Data Product Manifest

```json
{
  "dataProduct": {
    "name": "Orders Data Product",
    "domain": "order-management",
    "owner": {
      "team": "Order Platform Team",
      "contact": "order-team@company.com",
      "slackChannel": "#order-platform"
    },
    "description": "Canonical order data including line items, pricing, and fulfillment status",
    "classification": "INTERNAL",
    "sla": {
      "availability": "99.9%",
      "latencyP95": "200ms",
      "freshness": "near-real-time (< 30 seconds)",
      "supportHours": "24x7"
    },
    "schema": {
      "format": "JSON",
      "version": "2.1.0",
      "schemaRef": "./schema.json"
    },
    "accessPatterns": [
      {
        "type": "REST_API",
        "endpoint": "/api/data-products/orders",
        "description": "Synchronous query by order ID, customer ID, date range"
      },
      {
        "type": "EVENT_STREAM",
        "destination": "order-events-exchange",
        "description": "Real-time order lifecycle events (created, updated, shipped)"
      },
      {
        "type": "BATCH_EXPORT",
        "schedule": "daily at 02:00 UTC",
        "format": "CSV",
        "description": "Full order extract for analytics"
      }
    ],
    "qualityMetrics": {
      "completeness": ">= 99%",
      "accuracy": "validated against source system",
      "timeliness": "< 30 seconds from source change",
      "uniqueness": "order_id is globally unique"
    }
  }
}
```

#### Data Product API Implementation

```xml
<!-- data-product-orders.xml -->
<flow name="data-product-orders-api">
    <http:listener config-ref="HTTPS_Listener"
                   path="/api/data-products/orders/*" />

    <apikit:router config-ref="orders-dp-config" />
</flow>

<!-- Query by ID -->
<flow name="get:\orders\(orderId):orders-dp-config">
    <flow-ref name="data-quality-pre-check" />

    <db:select config-ref="OrdersDB">
        <db:sql>SELECT o.*, c.name as customer_name, c.email
               FROM orders o
               JOIN customers c ON o.customer_id = c.id
               WHERE o.id = :orderId</db:sql>
        <db:input-parameters>#[{ orderId: attributes.uriParams.orderId }]</db:input-parameters>
    </db:select>

    <!-- Transform to canonical data product schema -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    data: {
        orderId: payload[0].id,
        customer: {
            id: payload[0].customer_id,
            name: payload[0].customer_name,
            email: payload[0].email
        },
        lineItems: (payload[0].items_json read "application/json") default [],
        pricing: {
            subtotal: payload[0].subtotal,
            tax: payload[0].tax,
            total: payload[0].total,
            currency: payload[0].currency default "USD"
        },
        status: payload[0].status,
        timestamps: {
            created: payload[0].created_at,
            updated: payload[0].updated_at,
            shipped: payload[0].shipped_at
        }
    },
    metadata: {
        dataProduct: "orders",
        version: "2.1.0",
        generatedAt: now(),
        qualityScore: vars.qualityScore default 1.0
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>

<!-- Batch query with filtering -->
<flow name="get:\orders:orders-dp-config">
    <db:select config-ref="OrdersDB">
        <db:sql>SELECT o.*, c.name as customer_name
               FROM orders o
               JOIN customers c ON o.customer_id = c.id
               WHERE (:status IS NULL OR o.status = :status)
               AND (:fromDate IS NULL OR o.created_at >= :fromDate)
               AND (:toDate IS NULL OR o.created_at &lt;= :toDate)
               ORDER BY o.created_at DESC
               LIMIT :limit OFFSET :offset</db:sql>
        <db:input-parameters>#[{
            status: attributes.queryParams.status,
            fromDate: attributes.queryParams.fromDate,
            toDate: attributes.queryParams.toDate,
            limit: (attributes.queryParams.limit default "50") as Number,
            offset: (attributes.queryParams.offset default "0") as Number
        }]</db:input-parameters>
    </db:select>

    <!-- Paginated response with data product metadata -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    data: payload map (order) -> {
        orderId: order.id,
        customerName: order.customer_name,
        total: order.total,
        status: order.status,
        createdAt: order.created_at
    },
    pagination: {
        offset: (attributes.queryParams.offset default "0") as Number,
        limit: (attributes.queryParams.limit default "50") as Number,
        total: vars.totalCount default 0
    },
    metadata: {
        dataProduct: "orders",
        version: "2.1.0",
        generatedAt: now()
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Data Quality Checks

```xml
<!-- data-quality-checks.xml -->
<sub-flow name="data-quality-pre-check">
    <!-- Validate source freshness -->
    <db:select config-ref="OrdersDB">
        <db:sql>SELECT MAX(updated_at) as last_update FROM orders</db:sql>
    </db:select>

    <set-variable variableName="lastUpdate" value="#[payload[0].last_update]" />

    <choice>
        <when expression="#[
            (now() as Number { unit: 'seconds' }) -
            (vars.lastUpdate as DateTime as Number { unit: 'seconds' }) > 300
        ]">
            <!-- Data is stale (> 5 minutes) — add warning header -->
            <set-variable variableName="qualityScore" value="#[0.8]" />
            <logger level="WARN"
                    message="Data product 'orders' source data is stale. Last update: #[vars.lastUpdate]" />
        </when>
        <otherwise>
            <set-variable variableName="qualityScore" value="#[1.0]" />
        </otherwise>
    </choice>
</sub-flow>
```

#### Federated Governance Model

| Governance Layer | Scope | Owner |
|-----------------|-------|-------|
| **Platform standards** | API design guidelines, naming, security policies | Platform team (C4E) |
| **Data product standards** | Schema format, metadata requirements, SLA template | Data governance team |
| **Domain data policies** | What data to expose, access rules, refresh frequency | Domain team |
| **Consumer onboarding** | Self-serve via Exchange, API Manager approval | Automated + domain team |

#### Discovery via Anypoint Exchange

```
Exchange Catalog (Data Products):
┌─────────────────────────────────────────────────────────────┐
│ Search: "order data"                                        │
│                                                             │
│ Results:                                                    │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Orders Data Product API v2.1                            │ │
│ │ Domain: Order Management                                │ │
│ │ Owner: Order Platform Team                              │ │
│ │ SLA: 99.9% | P95: 200ms | Freshness: < 30s             │ │
│ │ Access: REST API, Event Stream, Batch Export             │ │
│ │ [Try It] [Request Access] [Documentation]               │ │
│ └─────────────────────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────────────────────┐ │
│ │ Customer Data Product API v3.0                          │ │
│ │ Domain: Customer Management                             │ │
│ │ Owner: CRM Team                                         │ │
│ │ SLA: 99.95% | P95: 150ms | Freshness: real-time        │ │
│ │ Access: REST API, CDC Events                            │ │
│ │ [Try It] [Request Access] [Documentation]               │ │
│ └─────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### How It Works

1. **Identify domain boundaries** — each business domain owns its data and serves it as a product
2. **Define data product contracts** — standard manifest format with SLA, schema, access patterns
3. **Build domain APIs in MuleSoft** — each domain team builds and operates their data product API
4. **Publish to Anypoint Exchange** — consumers discover data products through the API catalog
5. **Govern with federated model** — platform team sets standards, domain teams implement and operate
6. **Monitor and enforce SLAs** — use Anypoint Monitoring for availability, latency, and freshness

### Gotchas

- **Data mesh is an organizational change, not a technology change.** MuleSoft provides the infrastructure, but success depends on domain teams accepting ownership of data quality and API operations. Without cultural buy-in, you just have decentralized chaos.
- **Not every domain needs a data product.** Start with 3-5 high-demand data domains. Expanding too quickly dilutes focus and overwhelms domain teams.
- **Cross-domain queries are hard.** If a consumer needs order + customer + product data joined, they must call three data products and join client-side — or you build a composite API (which starts to look like centralization again). Define clear guidance for when composite APIs are appropriate.
- **Schema versioning across domains must be coordinated.** If the Orders data product references customer IDs, and the Customer data product changes its ID format, both must coordinate. Use Anypoint Exchange API fragments for shared schemas.
- **Data freshness SLAs are harder to measure than availability SLAs.** Build automated freshness checks (last-update timestamps) into every data product and surface them in monitoring dashboards.

### Related

- [Domain-Driven API Design](../domain-driven-api-design/) — domain boundaries map to data product boundaries
- [CQRS Implementation](../cqrs-implementation/) — CQRS read models as data products
- [Application Network Topology](../application-network-topology/) — visualizing data product dependencies
- [C4E Setup Playbook](../c4e-setup-playbook/) — the platform team that enables data mesh
