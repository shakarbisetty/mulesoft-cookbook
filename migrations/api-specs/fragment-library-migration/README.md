## Migrate Inline Types to Exchange Fragments
> Extract inline API type definitions into reusable Exchange fragment libraries

### When to Use
- Multiple APIs share the same data models
- Inline types duplicated across specifications
- Need centralized governance of API data models

### Configuration / Code

#### 1. Create RAML Fragment Library

```yaml
# common-types.raml
#%RAML 1.0 Library
types:
  Customer:
    type: object
    properties:
      id: { type: integer, required: true }
      name: { type: string, required: true }
      email: string
    examples:
      example1: { id: 1, name: "Jane Doe", email: "jane@example.com" }
  Address:
    type: object
    properties:
      street: string
      city: string
      state: { type: string, maxLength: 2 }
      zip: string
```

#### 2. Exchange Descriptor

```json
{
    "main": "common-types.raml",
    "name": "Common Data Types",
    "classifier": "raml-fragment"
}
```

#### 3. Publish to Exchange

```bash
anypoint-cli-v4 exchange asset upload \
    --organization "My Org" \
    --name "Common Data Types" \
    --assetId "common-data-types" \
    --version "1.0.0" \
    --classifier "raml-fragment"
```

#### 4. Consume in API Specs

```yaml
#%RAML 1.0
title: Orders API
uses:
  common: exchange_modules/com.mycompany/common-data-types/1.0.0/common-types.raml
types:
  Order:
    type: object
    properties:
      id: integer
      customer: common.Customer
      shippingAddress: common.Address
```

### How It Works
1. RAML Libraries published to Exchange as `raml-fragment` assets
2. API specs reference fragments using `uses` keyword
3. Design Center and Studio resolve Exchange dependencies automatically
4. Fragment versions are pinned and updated independently

### Migration Checklist
- [ ] Audit all APIs for shared/duplicated types
- [ ] Group types into logical fragment libraries
- [ ] Publish fragments to Exchange
- [ ] Update API specs to reference fragments
- [ ] Remove inline definitions
- [ ] Test resolution in Design Center

### Gotchas
- Fragment version updates are not automatic for consumers
- Circular dependencies between fragments are not allowed
- Design Center may cache old versions

### Related
- [raml08-to-10](../raml08-to-10/) - RAML 1.0 prerequisite
- [raml-to-oas3](../raml-to-oas3/) - OpenAPI conversion
