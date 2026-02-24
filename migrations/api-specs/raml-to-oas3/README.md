## Convert RAML 1.0 to OpenAPI 3.0
> Convert RAML 1.0 API specifications to OpenAPI 3.0 (OAS3) format

### When to Use
- Standardizing on OpenAPI across the organization
- Need OAS-only tools (Swagger UI, Stoplight, Redoc)
- Publishing to non-MuleSoft gateways requiring OpenAPI

### Configuration / Code

#### 1. Using AMF CLI

```bash
npm install -g @aml-org/amf-client-js
amf parse api.raml --format-out OAS30 --output api.oas3.yaml
```

#### 2. Type Mapping

```yaml
# RAML 1.0
types:
  Customer:
    type: object
    properties:
      id: { type: integer, required: true }
      name: { type: string, minLength: 1 }

# OAS 3.0
components:
  schemas:
    Customer:
      type: object
      required: [id]
      properties:
        id: { type: integer }
        name: { type: string, minLength: 1 }
```

#### 3. Security Scheme Mapping

```yaml
# RAML 1.0
securitySchemes:
  oauth_2_0:
    type: OAuth 2.0
    settings:
      authorizationUri: https://auth.example.com/authorize
      accessTokenUri: https://auth.example.com/token
      authorizationGrants: [authorization_code]

# OAS 3.0
components:
  securitySchemes:
    oauth_2_0:
      type: oauth2
      flows:
        authorizationCode:
          authorizationUrl: https://auth.example.com/authorize
          tokenUrl: https://auth.example.com/token
          scopes: {}
```

#### 4. Traits to Parameters

```yaml
# RAML 1.0 trait
traits:
  paginated:
    queryParameters:
      page: { type: integer, default: 1 }
      size: { type: integer, default: 20 }

# OAS 3.0
components:
  parameters:
    pageParam:
      name: page
      in: query
      schema: { type: integer, default: 1 }
    sizeParam:
      name: size
      in: query
      schema: { type: integer, default: 20 }
```

### How It Works
1. RAML types map to OAS `components/schemas`
2. RAML traits map to OAS `components/parameters`
3. RAML `baseUri` maps to OAS `servers` array
4. RAML examples map to OAS `example` properties

### Migration Checklist
- [ ] Convert using AMF or Design Center export
- [ ] Verify all types mapped to schemas
- [ ] Check security scheme conversion
- [ ] Validate with Swagger Editor or Spectral
- [ ] Compare endpoint count between RAML and OAS
- [ ] Publish converted spec to Exchange

### Gotchas
- RAML union types map to OAS `oneOf` which some tools handle poorly
- RAML `!include` references are inlined during conversion
- RAML annotations become `x-` extensions in OAS

### Related
- [raml08-to-10](../raml08-to-10/) - Prepare RAML for conversion
- [swagger2-to-oas3](../swagger2-to-oas3/) - Swagger 2 to OAS3
- [fragment-library-migration](../fragment-library-migration/) - Exchange fragments
