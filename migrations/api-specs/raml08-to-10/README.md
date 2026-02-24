## RAML 0.8 to RAML 1.0 Migration
> Convert RAML 0.8 API specifications to RAML 1.0 syntax

### When to Use
- Legacy APIs defined in RAML 0.8 need updating for modern tooling
- API Manager or Design Center requires RAML 1.0
- Need RAML 1.0 features: types, libraries, overlays, annotations

### Configuration / Code

#### 1. Version Header

```yaml
# Before
#%RAML 0.8
# After
#%RAML 1.0
```

#### 2. Schemas to Types

```yaml
# RAML 0.8
schemas:
  - Customer: |
      { "type": "object", "properties": { "id": {"type": "integer"}, "name": {"type": "string"} } }

# RAML 1.0
types:
  Customer:
    type: object
    properties:
      id: { type: integer, required: true }
      name: { type: string, required: true }
```

#### 3. Resource Types (Array to Map)

```yaml
# RAML 0.8 (array of maps)
resourceTypes:
  - collection:
      get:
        responses:
          200:
            body:
              application/json:
                schema: <<resourcePathName>>

# RAML 1.0 (direct map, schema becomes type)
resourceTypes:
  collection:
    get:
      responses:
        200:
          body:
            application/json:
              type: <<resourcePathName>>
```

#### 4. Security Schemes (Array to Map)

```yaml
# RAML 0.8 (array)
securitySchemes:
  - oauth_2_0:
      type: OAuth 2.0
      settings:
        authorizationUri: https://auth.example.com/authorize
        accessTokenUri: https://auth.example.com/token

# RAML 1.0 (map)
securitySchemes:
  oauth_2_0:
    type: OAuth 2.0
    settings:
      authorizationUri: https://auth.example.com/authorize
      accessTokenUri: https://auth.example.com/token
```

#### 5. Libraries (New in RAML 1.0)

```yaml
# types/customer-types.raml
#%RAML 1.0 Library
types:
  Customer:
    type: object
    properties:
      id: integer
      name: string

# Main API
#%RAML 1.0
title: Customer API
uses:
  types: types/customer-types.raml
/customers:
  get:
    responses:
      200:
        body:
          application/json:
            type: types.Customer[]
```

### How It Works
1. RAML 1.0 replaced `schemas` with `types` and introduced a native type system
2. Resource types, traits, and security schemes changed from arrays-of-maps to direct maps
3. RAML 1.0 added libraries (`uses`), overlays, extensions, and annotations

### Migration Checklist
- [ ] Update version header to `#%RAML 1.0`
- [ ] Convert `schemas` to `types` with RAML type syntax
- [ ] Replace `schema` references with `type`
- [ ] Remove array wrappers from `resourceTypes`, `traits`, `securitySchemes`
- [ ] Extract common types into libraries
- [ ] Validate with API Designer

### Gotchas
- `schemas` keyword still works but is deprecated
- RAML 0.8 `!!include` becomes `!include` (single bang)
- Design Center may auto-convert some syntax but verify the result

### Related
- [raml-to-oas3](../raml-to-oas3/) - Convert to OpenAPI
- [fragment-library-migration](../fragment-library-migration/) - Exchange fragments
- [design-center-to-code-first](../design-center-to-code-first/) - Code-first development
