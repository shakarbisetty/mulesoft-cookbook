## OAS 3.0 Component Fragments
> Break large OpenAPI specs into reusable component files.

### When to Use
- Large API specs that are hard to maintain as a single file
- Sharing schemas, parameters, or responses across APIs
- Team collaboration where different teams own different components

### Configuration / Code

**schemas/Order.yaml:**
```yaml
type: object
required: [id, customerId, total]
properties:
  id:
    type: string
    format: uuid
  customerId:
    type: string
  total:
    type: number
    format: double
  status:
    type: string
    enum: [pending, confirmed, shipped, delivered]
  createdAt:
    type: string
    format: date-time
```

**Main spec referencing fragments:**
```yaml
openapi: 3.0.3
info:
  title: Orders API
  version: 1.0.0
paths:
  /orders:
    get:
      responses:
        200:
          content:
            application/json:
              schema:
                type: array
                items:
                  $ref: "./schemas/Order.yaml"
    post:
      requestBody:
        content:
          application/json:
            schema:
              $ref: "./schemas/Order.yaml"
```

### How It Works
1. Components are defined in separate files (schemas, parameters, responses)
2. Main spec uses `$ref` to reference external files
3. Tools resolve references during build/validation
4. Fragments can be published to Exchange as API fragments

### Gotchas
- Circular `$ref` references cause infinite loops in some tools
- Relative paths in `$ref` must be correct from the main spec location
- Not all tools support external file references — test your toolchain
- Fragment versioning must align with the main spec version

### Related
- [RAML Traits](../raml-traits/) — RAML reusability
- [Shared Data Types](../shared-data-types/) — shared type libraries
