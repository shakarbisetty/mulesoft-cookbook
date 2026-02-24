# Error Handling Patterns

> 51 production-grade error handling recipes for MuleSoft Mule 4 applications.

## Categories

| Category | Recipes | Description |
|----------|---------|-------------|
| [global/](global/) | 5 | Default handlers, continue vs propagate, shared libraries, type mapping |
| [http-errors/](http-errors/) | 6 | Status code mapping, RFC 7807, SOAP-to-REST faults, GraphQL errors |
| [retry/](retry/) | 5 | Until-successful, exponential backoff, circuit breaker, reconnection |
| [dead-letter-queues/](dead-letter-queues/) | 5 | Anypoint MQ DLQ, JMS DLQ, VM queue DLQ, reprocessing |
| [async-errors/](async-errors/) | 5 | Async scope, scatter-gather, parallel for-each, batch step errors |
| [transactions/](transactions/) | 4 | XA rollback, local transactions, saga compensation, selective rollback |
| [connector-errors/](connector-errors/) | 7 | DB pool exhaustion, deadlock retry, HTTP timeout, Salesforce errors |
| [notifications/](notifications/) | 5 | Slack webhook, Teams adaptive card, email SMTP, structured logging |
| [validation/](validation/) | 5 | RAML/OAS validation, JSON schema, custom business rules, XSD |
| [recovery/](recovery/) | 4 | Cached fallback, fallback routing, partial success 207, bulkhead |

## Related

- [DataWeave Error Handling patterns](../dataweave/patterns/07-error-handling/) — DataWeave-level error handling (try, default, orElse)

---

Part of [MuleSoft Cookbook](https://github.com/shakarbisetty/mulesoft-cookbook)
