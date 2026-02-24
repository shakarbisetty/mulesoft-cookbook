# MuleSoft Vibes — Build Integrations with Natural Language

> From prompt to production: create Mule projects, generate flows, write DataWeave, and deploy — all from natural language.

## What is MuleSoft Vibes?

MuleSoft Vibes (GA October 2025) is an agentic AI layer built into Anypoint Code Builder. It understands the MuleSoft ecosystem — Mule XML flow structure, DataWeave syntax, connector schemas, RAML/OAS specs, and MUnit tests — and generates production-quality code from natural language prompts.

Previously called "MuleSoft Dev Agent," Vibes is the same underlying capability. When accessed through external IDEs (Cursor, VS Code, Windsurf), it's exposed via the [MuleSoft MCP Server](../mcp-ide-setup/).

**Not a generic LLM wrapper.** Vibes routes through MuleSoft's AI Quality Pipeline, which normalizes and enriches prompts before generation — achieving ~90% syntactic validity and ~80% semantic correctness, compared to ~20%/~17% for raw direct prompting of the same models.

## Prerequisites

- Anypoint Platform account with Einstein-enabled Salesforce org
- Anypoint Code Builder (cloud or desktop)
- No additional cost — included with all Anypoint Platform subscriptions

## How It Works

```
Your Prompt
    ↓
AI Quality Pipeline (enrichment + validation)
    ↓
MuleSoft-Tuned Generation
    ↓
Project Context (open files, connectors, metadata)
    ↓
Generated Code → Review → Apply to Workspace
```

### Two Operating Modes

| Mode | Behavior | Use When |
|------|----------|----------|
| **Plan** | Returns a step-by-step plan with code snippets for review | Learning, complex multi-file changes, reviewing before applying |
| **Act** | Writes files and modifies XML in real time | Quick iterations, simple changes, confident prompts |

## What You Can Build

### 1. Full Integration Projects

```
Create a Mule project that syncs new orders from Shopify to Salesforce Opportunities.
Handle errors by logging to CloudWatch and sending an alert via email.
```

Vibes generates:
- `pom.xml` with correct connector versions (auto-resolved from Exchange)
- Mule XML flows with trigger, connector operations, DataWeave transformations
- Error handling with try-catch patterns
- Property placeholders for environment-specific config

### 2. API Specifications

```
Create an API spec in RAML format for an Order Management API with CRUD operations,
including OAuth 2.0 authentication, request/response validation, pagination on the
GET collection endpoint, and error definitions for 400, 401, 404, and 500.
```

Supports both RAML and OAS 3.0 generation.

### 3. DataWeave Transformations

```
Write a DataWeave transformation that merges two payloads: vars.customerData (JSON)
and payload (XML from SAP). Combine fields, convert all dates to ISO 8601, and
filter out records where status == "INACTIVE".
```

The AI Quality Pipeline understands DataWeave functions, operators, and output directives.

### 4. MUnit Test Suites

```
Generate a complete MUnit test suite for the order-sync flow in my project.
Include test cases for: success path, NetSuite 409 conflict, and Salesforce
query returning zero results.
```

AI generates mock data based on application metadata (real payload structures from connector schemas), covering both success and failure paths.

### 5. MCP Server Projects

```
Create a MuleSoft MCP Server containing these operations from Exchange:
Workday - Get Time Off Plan Balances, Workday - Enter Time Off,
Google Calendar - Create Event. Expose these as three MCP tools.
```

### 6. Deployment

```
Deploy the current project to CloudHub 2.0 in the production environment
using the us-east-1 region with 2 vCores.
```

## Rules System (Governance)

Rules embed organizational standards into every generation action, defined in natural language:

### Global Rules (apply to all projects)

```
Always use HTTPS for HTTP connector endpoints.
Never use BETA connector versions.
All error handlers must include a logger component.
Use property placeholders for all external URLs and credentials.
```

### Workspace Rules (scoped to one project)

```
Use the retry-pattern error handler for all HTTP requests in this project.
All DataWeave scripts must use explicit type coercion (no implicit casting).
```

Rules are stored in Anypoint Exchange and validate all generated code. Team leads define global rules; developers add workspace rules for project-specific constraints.

## Example Prompts (from Official Docs)

### Integration Flows

```
Build a Mule integration that exposes a REST API on /api/v1/employees,
queries Workday for employee records, transforms the response to flat JSON,
and caches the result for 5 minutes.
```

```
Sync new leads from Salesforce to Slack. Post to #new-leads with the lead
name, company, email, and deal value formatted as a card.
```

### DataWeave

```
Generate a DataWeave script to transform this Salesforce SOAP response into
a flat JSON array. Input: nested Account > Contacts > Contact structure.
Output: [{accountName, contactName, email, phone}].
```

### MUnit Tests

```
Add a test case to CustomerAPI.test.xml that tests the validation error when
the request body is missing the required email field.
```

### API Specs

```
Generate an OAS 3.0 spec for a User Authentication API with endpoints for
registration, login, JWT token refresh, and password reset. Include request
body schemas and response examples.
```

## ACB February 2026 — AI-Powered Mapper

The February 2026 Anypoint Code Builder release added intelligent DataWeave graphical mapping:

| Feature | What It Does |
|---------|--------------|
| **Intelligent automapping** | Matches fields by name across nested structures — no manual dragging |
| **Automatic array wrapping** | Detects when output expects an array and wraps mappings |
| **Common envelope patterns** | Supports `{ data: [...], meta: {...} }` wrapper patterns |
| **Override detection** | Warns before drag-and-drop overwrites handwritten DataWeave |
| **Type coercion** | Handles String↔Integer, Date↔String without explicit `as` casts |

**Workflow:** Vibes drafts the DataWeave script → mapper visualizes it → developer adjusts via drag-and-drop.

## MuleSoft MCP Server — 50+ Tools

When accessed through external IDEs, Vibes capabilities are exposed as MCP tools:

| Category | Tools | Examples |
|----------|-------|----------|
| **App Development** | 13 | Create projects, generate flows, generate MUnit tests |
| **App Management** | 5 | Deploy to CloudHub 2.0/RTF, manage API instances |
| **DataWeave** | 6 | Create DW projects, generate scripts, execute transformations |
| **Agent Networks** | 4 | Create/configure/deploy agent network projects |
| **Governance** | 3 | Add rulesets, validate APIs against governance rules |
| **Policy Management** | 2 | Manage API policies, create Flex Gateway policy projects |
| **Connector Development** | 3 | Generate custom connectors from specs (ACB only) |
| **Insights** | 2 | Platform analytics, asset reuse metrics |

See [MCP IDE Setup](../mcp-ide-setup/) for connecting external IDEs to these tools.

## Common Gotchas

- **Context window fills up** — Vibes shows a progress bar; when full, it starts a new task context and may lose prior turns
- **Environment configs need manual adjustment** — CloudHub properties, property placeholders for credentials
- **Use GA connector versions only** — BETA/SNAPSHOT connectors produce unreliable results
- **Cannot upload to Design Center directly** — API specs must be published manually to Exchange
- **No autonomous production deploy** — Act mode requires human confirmation for deployment
- **Included at no extra cost** — but requires an Einstein-enabled Salesforce org

## When NOT to Use Vibes

Vibes is powerful but has clear limitations. Knowing when to write code manually saves hours of debugging AI-generated output.

### Don't Use Vibes For:

| Scenario | Why | Better Approach |
|----------|-----|-----------------|
| **Complex batch jobs** | Vibes generates simple batch configs but misses block sizing, memory tuning, watermarking, aggregator patterns | Write batch XML manually using [block-size-optimization](../../performance/batch/block-size-optimization/) |
| **Custom error handling hierarchies** | Vibes adds basic try/on-error but doesn't understand layered error strategies, error type hierarchies, or cross-flow error propagation | Design error strategy first, then implement — see [error-handling](../../error-handling/) |
| **Performance-critical DataWeave** | Vibes uses readable but non-optimized DW — nested maps, unnecessary intermediate variables, no streaming consideration | Hand-write DW with streaming and lazy evaluation — see [dataweave patterns](../../dataweave/) |
| **Multi-flow orchestration** | Vibes generates individual flows well but doesn't understand flow-to-flow contracts, variable scoping across flow-refs, or async completion patterns | Design the orchestration architecture first, generate individual flows |
| **SAP/EDI/AS2 integrations** | Vibes has limited training data for complex B2B connectors — generates incomplete configs | Use [connector patterns](../../connectors/) as starting templates |
| **Security-critical flows** | Vibes doesn't understand OWASP risks, may generate injectable SQL, may skip input validation | Manual security review mandatory — see [OWASP mapping](../../api-management/security/owasp-api-top10-mapping/) |
| **Migration from Mule 3** | Vibes generates Mule 4 from scratch but can't read/convert existing Mule 3 XML | Use MMA first, then Vibes for individual flow improvements |

### Vibes Output Quality by Task Type

| Task | Syntactic Validity | Semantic Correctness | Recommended? |
|------|-------------------|---------------------|--------------|
| Simple REST API (CRUD) | ~95% | ~90% | Yes |
| DataWeave transforms | ~90% | ~80% | Yes, with review |
| MUnit test generation | ~85% | ~70% | Yes, but fix mocks |
| API spec (RAML/OAS) | ~90% | ~85% | Yes |
| Batch processing | ~75% | ~50% | Start manually |
| Complex error handling | ~80% | ~45% | Manual preferred |
| Multi-connector orchestration | ~70% | ~40% | Manual preferred |

### Workarounds for Vibes Limitations

1. **Break complex prompts into steps** — generate one flow at a time, not an entire project
2. **Provide input/output examples** — Vibes generates better DW when it sees sample data
3. **Use workspace rules** — encode your standards so Vibes follows them automatically
4. **Always review error handling** — add try blocks and error types Vibes misses
5. **Run MUnit immediately** — catch semantic errors before they reach staging

## References

- [MuleSoft Vibes GA Announcement](https://blogs.mulesoft.com/news/mulesoft-vibes-ga/)
- [Get Started with MuleSoft Vibes](https://blogs.mulesoft.com/news/mulesoft-vibes/)
- [Vibes MUnit Test Generation](https://blogs.mulesoft.com/news/mulesoft-vibes-munit-tests/)
- [Example Prompts](https://docs.mulesoft.com/anypoint-code-builder/a4d-prompt-examples)
- [MCP Server Tool Reference](https://docs.mulesoft.com/mulesoft-mcp-server/reference-mcp-tools)
- [ACB February 2026 Release](https://blogs.mulesoft.com/news/anypoint-code-builder-february-2026-release/)
- [Developing with Dev Agent](https://docs.mulesoft.com/anypoint-code-builder/int-ai-developing-integrations)
