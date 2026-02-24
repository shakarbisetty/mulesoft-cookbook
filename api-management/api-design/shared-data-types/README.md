## Shared Data Type Libraries
> Publish reusable data types to Exchange for consistent schemas across APIs.

### When to Use
- Common entities (Customer, Address, Money) used across multiple APIs
- Enforcing consistent field names and types organization-wide
- Reducing duplication in API spec maintenance

### Configuration / Code

**Exchange data type library:**
```raml
#%RAML 1.0 Library
types:
  Address:
    type: object
    properties:
      street: string
      city: string
      state: string
      postalCode:
        type: string
        pattern: "^[0-9]{5}(-[0-9]{4})?$"
      country:
        type: string
        enum: [US, CA, GB, AU]

  Money:
    type: object
    properties:
      amount:
        type: number
        format: double
      currency:
        type: string
        minLength: 3
        maxLength: 3
```

**Using in an API spec:**
```raml
#%RAML 1.0
title: Orders API
uses:
  common: exchange_modules/org-id/common-types/1.0.0/common-types.raml

/orders:
  post:
    body:
      application/json:
        properties:
          shippingAddress: common.Address
          total: common.Money
```

### How It Works
1. Data types are defined in a RAML Library
2. Library is published to Exchange as a reusable fragment
3. APIs import the library with `uses:` and reference types
4. Design Center auto-fetches Exchange dependencies

### Gotchas
- Versioning: changing a shared type affects all APIs that use it
- Use semantic versioning — breaking changes require a major version bump
- Exchange dependencies are resolved at design time, not runtime
- Test backward compatibility before publishing new type versions

### Related
- [OAS3 Fragments](../oas3-fragments/) — OAS component reuse
- [Resource Type Library](../resource-type-library/) — resource patterns
