## DataWeave Transform Policy
> Apply DataWeave transformations as a gateway policy for request/response manipulation.

### When to Use
- Header enrichment or removal at the gateway
- Response body transformation (XML to JSON, field filtering)
- Request normalization before backend processing

### Configuration / Code

```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: transform-response
spec:
  targetRef:
    name: products-api
  policyRef:
    name: dataweave
  config:
    requestTransform: |
      %dw 2.0
      output application/json
      ---
      {
        query: attributes.queryParams.q,
        page: attributes.queryParams.page as Number default 1
      }
    responseTransform: |
      %dw 2.0
      output application/json
      ---
      payload map {
        id: $.id,
        name: $.name
        // Strip internal fields before returning
      }
```

### How It Works
1. `requestTransform` modifies the request before it reaches the backend
2. `responseTransform` modifies the response before returning to the client
3. DataWeave expressions have access to payload, attributes, and headers
4. Transforms execute in the gateway — no backend changes needed

### Gotchas
- Large payloads in transforms add latency — keep transformations lightweight
- DataWeave version must match the gateway runtime version
- Errors in transforms return 500 — add error handling in the DW script
- Cannot access external resources (DB, HTTP) from within the transform

### Related
- [Rust WASM Policy](../rust-wasm-policy/) — complex custom logic
- [Header Injection](../header-injection/) — simpler header manipulation
