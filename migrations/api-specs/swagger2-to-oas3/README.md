## Swagger 2.0 to OpenAPI 3.0 Migration
> Convert Swagger 2.0 specifications to OpenAPI 3.0

### When to Use
- APIs defined in Swagger 2.0 need modernization
- Publishing to Anypoint Exchange which supports OAS 3.0 natively
- Need OAS 3.0 features: multiple servers, callbacks, links

### Configuration / Code

#### 1. Automated Conversion

```bash
curl -X POST "https://converter.swagger.io/api/convert" \
    -H "Content-Type: application/json" \
    -d @swagger2-spec.json -o oas3-spec.json
```

#### 2. Structural Changes

```yaml
# Swagger 2.0
swagger: "2.0"
info: { title: My API, version: "1.0" }
host: api.example.com
basePath: /v1
schemes: [https]
consumes: [application/json]
produces: [application/json]

# OpenAPI 3.0
openapi: "3.0.3"
info: { title: My API, version: "1.0" }
servers:
  - url: https://api.example.com/v1
```

#### 3. Request Body Migration

```yaml
# Swagger 2.0 (body parameter)
parameters:
  - in: body
    name: body
    schema:
      $ref: "#/definitions/Customer"

# OpenAPI 3.0 (requestBody)
requestBody:
  required: true
  content:
    application/json:
      schema:
        $ref: "#/components/schemas/Customer"
```

#### 4. Definitions to Components

```yaml
# Swagger 2.0: definitions/Customer
# OpenAPI 3.0: components/schemas/Customer
# $ref: "#/definitions/X" -> $ref: "#/components/schemas/X"
```

#### 5. File Upload

```yaml
# Swagger 2.0
parameters:
  - in: formData
    name: file
    type: file

# OpenAPI 3.0
requestBody:
  content:
    multipart/form-data:
      schema:
        type: object
        properties:
          file: { type: string, format: binary }
```

### How It Works
1. `swagger: "2.0"` becomes `openapi: "3.0.3"`
2. `host`/`basePath`/`schemes` consolidate into `servers` array
3. `definitions` moves to `components/schemas`
4. Body parameters become `requestBody` objects

### Migration Checklist
- [ ] Run automated converter
- [ ] Verify `servers` array
- [ ] Check `requestBody` conversions
- [ ] Update `$ref` paths
- [ ] Validate with Swagger Editor

### Gotchas
- Global `consumes`/`produces` must be per-operation in OAS 3.0
- Response codes must be strings (`"200"` not `200`)
- `securityDefinitions` becomes `components/securitySchemes`

### Related
- [raml-to-oas3](../raml-to-oas3/) - RAML to OAS conversion
- [fragment-library-migration](../fragment-library-migration/) - Exchange fragments
