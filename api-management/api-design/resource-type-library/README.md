## Resource Type Library
> Define standard CRUD resource types for consistent API structures.

### When to Use
- All your APIs follow similar CRUD patterns
- Standardizing collection vs. member resource behaviors
- Reducing boilerplate in large API specs

### Configuration / Code

**resourceTypes/collection.raml:**
```raml
#%RAML 1.0 ResourceType
description: Collection of <<resourcePathName>>
get:
  description: List all <<resourcePathName>>
  is: [paginated]
  responses:
    200:
      body:
        application/json:
          type: <<typeName>>[]
post:
  description: Create a new <<typeName | !singularize>>
  body:
    application/json:
      type: <<typeName | !singularize>>
  responses:
    201:
      body:
        application/json:
          type: <<typeName | !singularize>>
```

**Using the resource type:**
```raml
/orders:
  type: { collection: { typeName: Order } }
  /{orderId}:
    type: { member: { typeName: Order } }
```

### How It Works
1. Resource types define the standard structure for endpoints
2. `<<typeName>>` and `<<resourcePathName>>` are parameters filled at use
3. Collection type handles GET (list) and POST (create)
4. Member type handles GET (read), PUT (update), DELETE (remove)

### Gotchas
- Resource type parameters support RAML functions (`!singularize`, `!pluralize`)
- Resource types can compose traits — `is: [paginated]` inside a resource type
- Overlapping definitions between resource type and endpoint cause merge conflicts
- Keep resource types in Exchange for cross-API reuse

### Related
- [RAML Traits](../raml-traits/) — reusable traits
- [OAS-RAML Interop](../oas-raml-interop/) — format interoperability
