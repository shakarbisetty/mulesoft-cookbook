## RAML Traits for Reusable API Patterns
> Define reusable traits for pagination, filtering, and error responses.

### When to Use
- Multiple endpoints share the same query parameters (pagination, sorting)
- Standardizing error response formats across APIs
- DRY API specs — define once, apply many times

### Configuration / Code

**traits/paginated.raml:**
```raml
#%RAML 1.0 Trait
queryParameters:
  offset:
    type: integer
    default: 0
    description: Number of items to skip
  limit:
    type: integer
    default: 20
    maximum: 100
    description: Maximum items to return
responses:
  200:
    headers:
      X-Total-Count:
        type: integer
        description: Total number of items
```

**Using the trait:**
```raml
#%RAML 1.0
title: Orders API
traits:
  paginated: !include traits/paginated.raml

/orders:
  get:
    is: [paginated]
    responses:
      200:
        body:
          application/json:
            type: Order[]
```

### How It Works
1. Traits define reusable API fragments (params, headers, responses)
2. `is: [traitName]` applies the trait to an endpoint
3. Traits can accept parameters for customization
4. Generated documentation and SDK reflect trait-defined elements

### Gotchas
- Trait parameters use `<<paramName>>` syntax — easy to forget the double angle brackets
- Traits are merged with endpoint definitions — conflicts are resolved by endpoint winning
- Complex traits make specs harder to read — keep traits focused
- Traits published to Exchange can be shared across APIs

### Related
- [Resource Type Library](../resource-type-library/) — reusable resource types
- [Shared Data Types](../shared-data-types/) — shared type definitions
