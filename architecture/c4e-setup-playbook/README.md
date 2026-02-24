## C4E Setup Playbook
> Stand up a Center for Enablement that accelerates teams instead of blocking them

### When to Use
- Your organization has 5+ integration teams and no shared standards
- API duplication is rampant — multiple teams building overlapping connectors
- You need a governance body but your last "Center of Excellence" became a bottleneck
- MuleSoft platform adoption is stalling because teams do not know what assets exist

### Configuration / Code

#### C4E Org Chart

```
                    ┌──────────────────────┐
                    │    C4E Lead           │
                    │  (VP/Director level)  │
                    └──────────┬───────────┘
                               │
            ┌──────────────────┼──────────────────┐
            │                  │                   │
   ┌────────┴────────┐  ┌─────┴──────┐  ┌────────┴────────┐
   │  API Architects  │  │  Platform   │  │  Reuse Champions │
   │  (2-3 people)    │  │  Engineers  │  │  (1 per domain)  │
   │                  │  │  (2 people) │  │                  │
   │  - API reviews   │  │  - Runtime  │  │  - Embedded in   │
   │  - Design stds   │  │  - CI/CD    │  │    domain teams  │
   │  - RAML/OAS      │  │  - Env mgmt │  │  - Asset scout   │
   │    governance    │  │  - Monitoring│  │  - Adoption coach│
   └─────────────────┘  └────────────┘  └─────────────────┘
```

**Sizing guide:**
- 5-15 integration developers → 1 C4E Lead + 1 Architect + 1 Platform Eng
- 15-50 developers → Full structure above (6-8 people)
- 50+ developers → Add dedicated API Product Managers and a Developer Relations function

#### KPI Dashboard

| KPI | Target | Measurement | Frequency |
|-----|--------|-------------|-----------|
| **Reuse Rate** | ≥30% of new projects use existing assets | `(projects reusing assets / total projects) × 100` | Quarterly |
| **Time-to-First-API** | ≤2 weeks from request to production | Jira epic lead time for "new API" type | Monthly |
| **API Adoption** | Each published API has ≥2 consumers within 6 months | Exchange analytics: unique client-id registrations | Quarterly |
| **Defect Density** | ≤2 production incidents per API per quarter | Incident tracking system, tagged by API | Quarterly |
| **Exchange Catalog Coverage** | 100% of production APIs have published specs | `(APIs with Exchange listing / total production APIs) × 100` | Monthly |
| **Developer Satisfaction (NPS)** | ≥40 | Anonymous survey: "How easy is it to build integrations here?" | Semi-annual |

#### Governance Model: API Review Board

```
Developer submits API proposal (RAML/OAS spec + 1-page rationale)
           │
           ▼
  ┌────────────────────────┐
  │  Automated checks (CI) │
  │  - Naming conventions  │
  │  - Security policies   │
  │  - Versioning scheme   │
  │  - Fragment reuse      │
  └───────────┬────────────┘
              │
         PASS │           FAIL ──► Auto-reject with fix suggestions
              ▼
  ┌────────────────────────┐
  │  Reuse Champion review │    ◄── "Does this overlap with an existing asset?"
  │  (same-day turnaround) │
  └───────────┬────────────┘
              │
     NO OVERLAP │        OVERLAP ──► Recommend extending existing API
              ▼
  ┌────────────────────────┐
  │  API Architect review  │    ◄── "Is the design sound? Right tier?"
  │  (48-hour SLA)         │        Happens async; only escalates to
  └───────────┬────────────┘        sync meeting for complex cases
              │
         APPROVED ──► API published to Exchange (Design Center)
              │
              ▼
       Development begins
```

#### Exchange Publishing Workflow

```yaml
# .github/workflows/exchange-publish.yml (conceptual)
steps:
  - name: Validate RAML/OAS spec
    run: |
      # API spec linting — enforced naming, security schemes, examples
      anypoint-cli api-mgr:spec validate --spec api.raml

  - name: Check for duplicates
    run: |
      # Query Exchange for similar assets
      anypoint-cli exchange:asset:list --search "$API_NAME"
      # Fail if >80% name similarity with existing asset

  - name: Publish to Exchange
    run: |
      anypoint-cli exchange:asset:upload \
        --name "$API_NAME" \
        --version "$API_VERSION" \
        --classifier raml \
        --file api.raml

  - name: Notify Reuse Champions
    run: |
      # Post to Slack #c4e-new-assets channel
      curl -X POST "$SLACK_WEBHOOK" \
        -d '{"text": "New API published: '"$API_NAME"' v'"$API_VERSION"'"}'
```

#### Design Standards Checklist

| Standard | Rule | Rationale |
|----------|------|-----------|
| Naming | `{domain}-{capability}-{type}-api` (e.g., `order-fulfillment-process-api`) | Discoverable in Exchange search |
| Versioning | URL path versioning: `/v1/`, `/v2/` | Clear, cacheable, proxy-friendly |
| Security | All APIs require client-id enforcement + OAuth 2.0 for external | Zero-trust by default |
| Error format | RFC 7807 Problem Details | Consistent error handling across teams |
| Pagination | Cursor-based for lists > 100 items | Stable pagination under concurrent writes |
| RAML fragments | Must use Exchange-published traits for common patterns | Reuse at the spec level, not just runtime |

### How It Works
1. **Week 1-2**: Executive sponsor names C4E Lead, allocates headcount
2. **Week 3-4**: C4E Lead audits existing APIs, identifies duplication, drafts design standards v1
3. **Month 2**: Recruit Reuse Champions from each domain team (part-time, 20% allocation)
4. **Month 2-3**: Implement automated spec checks in CI; publish design standards to Exchange as a documentation asset
5. **Month 3**: Launch API Review Board with 48-hour SLA; start tracking KPIs
6. **Month 4-6**: Reuse Champions identify top 5 cross-domain reuse candidates; C4E architects build them
7. **Quarter 3+**: Shift from "review and approve" to "enable and coach" — reduce review friction as teams internalize standards

### Gotchas
- **C4E becomes a bottleneck if too centralized.** The review board must have SLAs. If reviews take longer than 48 hours, teams will route around the C4E. Use automated checks to handle 80% of reviews without human involvement
- **Mandate vs enable.** A C4E that only says "no" gets bypassed. Spend 70% of effort building reusable assets and 30% on governance. If the ratio flips, you have a Center of Obstruction
- **Reuse Champions must have authority.** If they are junior developers with no ability to push back on duplication, the role is ceremonial. They need backing from domain leads
- **Do not measure success by number of APIs.** Measure by consumer adoption and developer satisfaction. A catalog of 200 unused APIs is worse than 30 well-adopted ones
- **Design standards must be living documents.** Version them. Review quarterly. If teams are consistently requesting exceptions, the standard is wrong — update it
- **Avoid the "platform team builds everything" trap.** C4E enables domain teams to self-serve. If every API goes through C4E for implementation, you have a resource bottleneck, not an enablement function

### Related
- [API-Led Anti-Patterns](../api-led-anti-patterns/) — What the C4E should be catching in reviews
- [Application Network Topology](../application-network-topology/) — How to visualize the catalog the C4E governs
- [Integration Maturity Model](../integration-maturity-model/) — C4E is typically a Level 3-4 capability
