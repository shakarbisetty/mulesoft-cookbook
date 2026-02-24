## Vibes Prompt Engineering
> Write effective prompts for MuleSoft Vibes flow generation with proven patterns and templates.

### When to Use
- You are using Vibes to generate Mule flows and want better output quality
- You want template prompts for common integration scenarios
- You need to understand what Vibes can and cannot infer from a prompt
- You are training a team to use Vibes effectively and need standardized prompt patterns

### Configuration / Code

**Prompt pattern structure — the 5-part framework:**

```
1. CONTEXT:    What system/domain is this for?
2. INPUT:      What data comes in? (format, schema, source)
3. OUTPUT:     What should the result look like? (format, schema, destination)
4. ERRORS:     What can go wrong? How should errors be handled?
5. CONNECTORS: Which specific MuleSoft connectors to use?
```

**Good vs bad prompt examples:**

| Aspect | Bad Prompt | Good Prompt |
|--------|-----------|-------------|
| **Scope** | "Create an API" | "Create a REST API with GET /customers/{id} that queries a MySQL database and returns JSON" |
| **Input** | (not specified) | "Input: POST body with fields orderId (string), items (array of {sku, qty, price}), customerId (string)" |
| **Error handling** | (not specified) | "On DB timeout, return 504. On validation failure, return 400 with field-level errors. On unknown errors, return 500 with correlation ID" |
| **Connectors** | "Connect to a database" | "Use the Database connector with MySQL config, connection pool max 10" |
| **Output** | "Return the data" | "Return JSON: {customer: {id, name, email, orders: [{id, date, total}]}, metadata: {requestId, timestamp}}" |

**Template prompt — REST API with database:**

```
Create a Mule 4 flow for a REST API:

ENDPOINT: GET /api/v1/customers/{customerId}/orders
LISTENER: HTTP Listener on port 8081, path /api/v1/*

PROCESSING:
1. Extract customerId from URI params
2. Validate customerId is not empty (raise APP:VALIDATION if empty)
3. Query MySQL database: SELECT * FROM orders WHERE customer_id = :customerId ORDER BY created_at DESC
4. Transform DB result to JSON response:
   {
     "customerId": "<from path>",
     "orders": [
       {
         "orderId": "<from DB>",
         "total": <from DB>,
         "status": "<from DB>",
         "createdAt": "<from DB, ISO 8601>"
       }
     ],
     "count": <number of orders>
   }

ERROR HANDLING:
- DB:CONNECTIVITY → 503, {"error": "Database unavailable"}
- DB:QUERY_EXECUTION → 500, {"error": "Query failed"}
- APP:VALIDATION → 400, {"error": "Customer ID is required"}
- ANY → 500, {"error": "Internal server error", "correlationId": correlationId}

REQUIREMENTS:
- Use Database connector (not HTTP to a DB proxy)
- Externalize DB connection string to secure properties
- Add logger before and after DB query with correlationId
- Name all processors with descriptive doc:name attributes
```

**Template prompt — file processing with batch:**

```
Create a Mule 4 batch flow:

TRIGGER: Poll SFTP server every 15 minutes for CSV files in /inbound/

PROCESSING:
1. Read CSV file (headers: employeeId, firstName, lastName, department, salary)
2. Batch process each row:
   Step 1 (validate): Reject rows where salary <= 0 or employeeId is empty
   Step 2 (transform): Convert to JSON, add processedAt timestamp
   Step 3 (upsert): Upsert to PostgreSQL employees table on employeeId

ON COMPLETE:
- Log summary: processed, successful, failed counts
- Move original file to /archive/ with timestamp suffix
- If failed > 10%, send alert email to admin@company.com

ERROR HANDLING:
- SFTP:CONNECTIVITY → log and skip this poll cycle
- DB:CONNECTIVITY → fail the batch, trigger alert
- Per-record DB errors → skip record, continue batch

REQUIREMENTS:
- Use SFTP connector with key-based auth (externalize key path)
- maxFailedRecords = 20
- Batch block size = 200
- Name all processors with descriptive doc:name
```

**Template prompt — event-driven with Anypoint MQ:**

```
Create a Mule 4 flow for event processing:

SOURCE: Anypoint MQ subscriber on queue "order-events"
MESSAGE FORMAT: JSON with fields: eventType, orderId, timestamp, payload

ROUTING by eventType:
- "ORDER_CREATED" → POST to Fulfillment API (http://fulfillment-api/v1/orders)
- "ORDER_CANCELLED" → POST to Refund API (http://refund-api/v1/refunds)
- "ORDER_UPDATED" → PUT to Inventory API (http://inventory-api/v1/stock)
- Unknown eventType → log warning, acknowledge message, do not process

ERROR HANDLING:
- HTTP:TIMEOUT on any API call → publish to DLQ "order-events-dlq" with original message + error details
- HTTP:CONNECTIVITY → retry 3 times with 2-second delay, then DLQ
- ANY → DLQ with full error context

REQUIREMENTS:
- Use Choice router (not scatter-gather)
- Acknowledge MQ message only after successful processing
- Add correlationId from message to all outbound HTTP headers
- Externalize all API URLs to properties
```

**Anti-patterns — prompts that produce poor results:**

```
BAD: "Build me a Salesforce integration"
WHY: No specifics on objects, operations, direction, or error handling.
Vibes will guess and probably generate a basic SOQL query with no structure.

BAD: "Create an API that does everything the RAML spec says"
WHY: Vibes cannot read attached files or RAML specs. You must describe
the endpoints, schemas, and behavior inline in the prompt.

BAD: "Make it production-ready"
WHY: "Production-ready" means different things. Be specific:
externalized configs, error handling, logging, retry logic, monitoring.

BAD: "Add security"
WHY: Which security? OAuth 2.0 client credentials? Basic auth?
API gateway policies? TLS? Be explicit about the security model.
```

### How It Works
1. Start with the 5-part framework: Context, Input, Output, Errors, Connectors
2. For each section, provide concrete details — schema shapes, field names, HTTP paths, error codes
3. Specify connector types explicitly (Database, not "connect to DB") to prevent Vibes from guessing
4. Include error handling instructions with specific error types and response codes
5. Add non-functional requirements: logging, property externalization, naming conventions
6. Review Vibes output against the original prompt — verify every requirement was addressed

### Gotchas
- **Vibes context window limits**: Very long prompts (1000+ words) may cause Vibes to lose track of later requirements. Keep prompts under 500 words and split complex flows into sub-flow prompts
- **Ambiguous requirements generate ambiguous flows**: "Handle errors appropriately" produces generic try-catch. Spell out every error type and its response
- **Vibes cannot read external files**: RAML specs, JSON schemas, or sample data files cannot be attached. Inline the relevant parts in your prompt
- **Connector version assumptions**: Vibes may generate XML for older connector versions. Verify the generated namespace URIs match your Mule runtime version
- **No property externalization by default**: Vibes hardcodes URLs, credentials, and config values. Always include "externalize to secure properties" in your prompt
- **Generated doc:name values**: Vibes may generate unhelpful doc:name values like "Transform Message" for every transform. Specify naming conventions in your prompt

### Related
- [Vibes Code Review Patterns](../vibes-code-review-patterns/)
- [Vibes Governance](../vibes-governance/)
- [Vibes MUnit Generation](../../devops/testing/vibes-munit-generation/)
