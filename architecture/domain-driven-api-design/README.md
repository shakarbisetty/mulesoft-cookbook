## Domain-Driven API Design
> Map business domains to API boundaries using bounded contexts, not database tables

### When to Use
- You are designing APIs for a greenfield integration platform and need to decide API scope
- Existing APIs are "anemic" — they mirror database tables (CRUD) instead of business capabilities
- Teams argue about which API owns a shared entity (e.g., "Customer" in Sales vs Support)
- You want event-driven boundaries that align with organizational ownership

### Configuration / Code

#### Example: Retail Domain Decomposition

```
Business Domain: Retail E-Commerce
  │
  ├─ Order Management (Bounded Context)
  │    └─ order-process-api
  │         Resources: /orders, /orders/{id}/status, /orders/{id}/cancel
  │         Owns: Order, OrderLine, OrderStatus
  │         Events: ORDER_CREATED, ORDER_SHIPPED, ORDER_CANCELLED
  │
  ├─ Inventory (Bounded Context)
  │    └─ inventory-process-api
  │         Resources: /stock-levels, /reservations, /warehouses/{id}/inventory
  │         Owns: StockLevel, Reservation, Warehouse
  │         Events: STOCK_RESERVED, STOCK_DEPLETED, REORDER_TRIGGERED
  │
  ├─ Customer (Bounded Context)
  │    └─ customer-process-api
  │         Resources: /customers, /customers/{id}/preferences, /loyalty
  │         Owns: Customer, Address, LoyaltyPoints, Preferences
  │         Events: CUSTOMER_REGISTERED, PROFILE_UPDATED
  │
  └─ Payment (Bounded Context)
       └─ payment-process-api
            Resources: /payments, /refunds, /payment-methods
            Owns: Payment, Refund, PaymentMethod
            Events: PAYMENT_CAPTURED, PAYMENT_FAILED, REFUND_ISSUED
```

**Key principle**: Each bounded context owns its data and exposes it through its API. No direct database sharing between contexts.

#### Domain Boundary Identification Checklist

| Question | If YES | If NO |
|----------|--------|-------|
| Does this data change on a different cadence than the rest? | Separate context | Might be same context |
| Is there a different team responsible for this capability? | Separate context | Could be same context |
| Would changes to this entity's schema break unrelated consumers? | Separate context — isolate the blast radius | Same context is safe |
| Does the same word ("Customer") mean different things here? | Separate contexts with distinct models | Same context |
| Could this capability be replaced independently? | Separate context | Likely coupled, same context |
| Does this have its own lifecycle (create, approve, fulfill, close)? | Separate context | Probably part of a larger lifecycle |

#### Shared Entities: The Context Map

The same real-world entity appears in multiple bounded contexts with different shapes:

```
         "Customer" across bounded contexts:

  ┌─────────────────────┐    ┌─────────────────────┐
  │  Order Context       │    │  Customer Context    │
  │                      │    │                      │
  │  OrderCustomer {     │    │  Customer {           │
  │    customerId        │    │    id                 │
  │    shippingAddress   │    │    name               │
  │    contactEmail      │    │    email              │
  │  }                   │    │    addresses[]        │
  │                      │    │    loyaltyTier        │
  │  (just enough to     │    │    preferences        │
  │   fulfill the order) │    │    registeredDate     │
  │                      │    │  }                    │
  └──────────┬───────────┘    │                      │
             │                │  (full customer       │
             │  Synced via    │   profile — source    │
             └─ event: ──────►│   of truth)           │
               CUSTOMER_      └──────────────────────┘
               REGISTERED

  Key: Order context does NOT call Customer API at order time.
  It keeps a local copy of the data it needs, updated via events.
```

#### Anti-Pattern: Anemic APIs

```
BAD: APIs that mirror database tables

  GET  /customers          ──► SELECT * FROM customers
  GET  /customers/{id}     ──► SELECT * FROM customers WHERE id = ?
  POST /customers          ──► INSERT INTO customers (...)
  PUT  /customers/{id}     ──► UPDATE customers SET ... WHERE id = ?

  This is a database proxy, not an API. It exposes internal schema,
  has no business logic, and breaks every time the database changes.
```

```
GOOD: APIs that expose business capabilities

  POST /customers/register         ──► Validates, creates, sends welcome event
  POST /customers/{id}/verify      ──► Triggers identity verification workflow
  GET  /customers/{id}/profile     ──► Aggregates from multiple sources
  POST /customers/{id}/merge       ──► Dedup logic, audit trail, event
  PUT  /customers/{id}/preferences ──► Updates with validation rules

  Resources represent actions and capabilities, not CRUD on tables.
```

#### Domain Event Contract Template

```yaml
# domain-events/order-events.yaml
eventType: ORDER_CREATED
version: "1.2"
source: order-process-api
schema:
  type: object
  required: [orderId, customerId, lineItems, total, currency]
  properties:
    orderId:
      type: string
      format: uuid
    customerId:
      type: string
    lineItems:
      type: array
      items:
        type: object
        properties:
          productId: { type: string }
          quantity: { type: integer, minimum: 1 }
          unitPrice: { type: number }
    total:
      type: number
    currency:
      type: string
      enum: [USD, EUR, GBP]
    createdAt:
      type: string
      format: date-time
consumers:
  - inventory-process-api    # reserves stock
  - notification-service     # sends confirmation
  - analytics-pipeline       # tracks revenue
compatibilityPolicy: backward  # new fields OK, removing fields = new version
```

#### Mapping Domains to API Tiers

```
  Domain: Order Management
  │
  ├─ Experience APIs (consumer-specific)
  │    ├─ exp-mobile-checkout   (mobile app flow)
  │    └─ exp-partner-orders    (B2B partner format)
  │
  ├─ Process APIs (domain logic)
  │    └─ prc-order-orchestration
  │         - Validates order against inventory
  │         - Calculates tax and shipping
  │         - Publishes ORDER_CREATED event
  │         - Orchestrates payment capture
  │
  └─ System APIs (backend access)
       ├─ sys-order-db          (order database)
       ├─ sys-erp-orders        (SAP/Oracle ERP)
       └─ sys-shipping-provider (FedEx/UPS API)

  Rule: Process API is the domain boundary owner.
  System APIs are internal implementation details.
  Experience APIs are consumer-facing adapters.
```

### How It Works
1. **Event Storm** with business stakeholders: identify commands ("Place Order"), events ("Order Placed"), and entities ("Order", "LineItem") on sticky notes
2. **Group by bounded context**: entities and events that change together and are owned by the same team belong in one context
3. **Draw context map**: identify relationships — upstream/downstream, shared kernel, anti-corruption layer
4. **Define API boundaries**: one process API per bounded context. The process API owns the domain logic and data
5. **Design event contracts**: each context publishes events for state changes that other contexts care about
6. **Implement anti-corruption layers**: when consuming data from another context, translate it into your local model. Never let another context's schema leak into yours

### Gotchas
- **Shared entities across domains are the hardest problem.** "Customer" means different things in Order, Support, and Marketing contexts. Do not create a single "Customer API" that tries to serve all of them. Each context keeps its own projection of the data it needs
- **Domain event contracts are a public API.** Treat them with the same versioning rigor as HTTP APIs. Use backward-compatible evolution (add fields, do not remove or rename)
- **Do not start with the database schema.** Start with the business capabilities and work backward to storage. If your API resources look like your database tables, you are doing it wrong
- **Organizational alignment matters more than technical purity.** If two bounded contexts are owned by the same team and always change together, merging them is pragmatic, not wrong
- **Anti-corruption layers add latency.** If two contexts exchange data at high frequency, the translation overhead may justify tighter coupling or a shared event format. This is a conscious trade-off, not a failure

### Related
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — Anemic APIs are a symptom of ignoring domain boundaries
- [Event-Driven Architecture](../event-driven-architecture-mulesoft/) — Domain events are the communication backbone between bounded contexts
- [Application Network Topology](../application-network-topology/) — Visualize how your domains interconnect
