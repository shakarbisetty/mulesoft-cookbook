## API-Led Anti-Patterns
> When 3-tier API-led connectivity is overkill — and what to do instead

### When to Use
- You have adopted MuleSoft's API-led pattern but your integration graph feels bloated
- Teams are building "pass-through" system or experience APIs that add latency without logic
- You suspect you have more APIs than business capabilities
- Stakeholders complain about time-to-delivery despite having "reusable" assets

### Configuration / Code

#### Decision Tree: Do You Need This Tier?

```
START: New integration requirement
  │
  ├─ Does the consumer need a unique data shape, auth, or rate limit?
  │    YES ──► Experience API justified
  │    NO  ──► Skip experience tier; consumer hits process API directly
  │
  ├─ Is there business logic, orchestration, or data enrichment?
  │    YES ──► Process API justified
  │    NO  ──► Skip process tier; experience (or consumer) hits system API
  │
  └─ Does the backend need protocol translation, pagination, or error normalization?
       YES ──► System API justified
       NO  ──► Skip system tier; call backend directly with a connector
```

#### Anti-Pattern 1: Experience API Explosion

One experience API per consumer, each a near-identical copy with trivial field renames.

```
BEFORE (6 APIs, 3 tiers):

  Mobile App ──► exp-mobile-orders ──┐
  Web App    ──► exp-web-orders   ──┤
  Partner    ──► exp-partner-orders ─┤
                                     ├──► prc-orders ──► sys-orders-db
                                     │                   sys-orders-erp
                                     │
  (3 experience APIs doing the same thing with minor field mapping)
```

```
AFTER (3 APIs, 2 tiers):

  Mobile App ─┐
  Web App    ─┼──► prc-orders (API policies handle per-consumer auth/rate-limit)
  Partner    ─┘         │
                        ├──► sys-orders-db
                        └──► sys-orders-erp

  Use API Manager policies (client-id enforcement, SLA tiers,
  response transformation policies) instead of separate experience APIs.
```

**Fix**: Use API Manager policies for per-consumer concerns. One well-designed process API with policy-based client differentiation replaces three experience APIs.

#### Anti-Pattern 2: Passthrough System APIs

System APIs that do nothing but call a single connector with zero transformation, error handling, or protocol translation.

```xml
<!-- BAD: sys-customer-sfdc literally just proxies Salesforce -->
<flow name="get-customer">
    <http:listener path="/customers/{id}" />
    <salesforce:query>
        <salesforce:salesforce-query>
            SELECT Id, Name, Email FROM Contact WHERE Id = ':id'
        </salesforce:salesforce-query>
    </salesforce:query>
    <!-- No transformation, no error handling, no caching — just a proxy -->
</flow>
```

**Fix**: If the only purpose is connector abstraction, use the connector directly in the process API. Create a system API only when you need to:
- Normalize errors from a flaky backend
- Handle pagination or batching
- Translate protocols (SOAP → REST, FTP → HTTP)
- Share the same backend access pattern across 3+ consumers

#### Anti-Pattern 3: Forced Process Tier

Every integration must go through a process API, even when there is no orchestration, enrichment, or business rule.

```
BEFORE: Simple CRUD with mandatory process tier

  exp-products ──► prc-products ──► sys-products-db
                   (does nothing)

AFTER: Collapse when no business logic exists

  exp-products ──► sys-products-db
  (or just one API: api-products)
```

**Fix**: If the process API is just forwarding requests, collapse it. A two-tier or even single-tier API is perfectly valid when the use case is simple.

#### Tier Collapse Scoring Matrix

| Signal | Score | Meaning |
|--------|-------|---------|
| API has <2 consumers | +1 | Low reuse, low blast radius |
| Zero transformation logic | +2 | Pure passthrough |
| Single backend system | +1 | No orchestration needed |
| No business rules or validation | +2 | No process logic |
| Same team owns both tiers | +1 | No organizational boundary |
| **Total ≥ 5** | | **Collapse the tier** |
| **Total 3-4** | | **Review — probably collapse** |
| **Total ≤ 2** | | **Keep the tier** |

### How It Works
1. Inventory your API catalog — count APIs per tier
2. For each experience API, ask: "Does this do anything that an API Manager policy cannot?"
3. For each system API, ask: "Is there a consumer other than one process API? Does it add error normalization, caching, or protocol translation?"
4. For each process API, ask: "Does this orchestrate, enrich, or apply business rules?"
5. Score each API against the collapse matrix above
6. Merge APIs that score ≥ 5 — redeploy, update consumer configurations, retire the old API
7. Document which tiers were intentionally skipped and why (for audit trail)

### Gotchas
- **"API-led doesn't mean always 3 tiers."** The original MuleSoft whitepaper describes a pattern, not a mandate. Forcing three tiers everywhere is the most common misinterpretation
- **Reuse argument is often premature.** Building a system API "for future reuse" when there is one consumer creates maintenance burden for speculative benefit. Apply YAGNI
- **Collapsing tiers is not the same as skipping governance.** You still need API specifications, versioning, and policies — just fewer deployment units
- **Latency adds up.** Every passthrough hop adds 5-20ms. At 3 tiers with 2 internal hops, you burn 10-40ms doing nothing
- **Watch for the "API count as KPI" trap.** Some orgs measure success by number of APIs published. This incentivizes splitting, not simplifying

### Related
- [Domain-Driven API Design](../domain-driven-api-design/) — How bounded contexts inform API boundaries (and prevent anemic APIs)
- [C4E Setup Playbook](../c4e-setup-playbook/) — Governance model that reviews API proposals before they proliferate
- [Microservices vs API-Led](../microservices-vs-api-led/) — When microservices thinking replaces API-led tiers entirely
