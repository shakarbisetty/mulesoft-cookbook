## OAS-RAML Interoperability
> Convert between RAML and OAS 3.0 formats and understand the trade-offs.

### When to Use
- Migrating API specs from RAML to OAS (or vice versa)
- Teams using different spec formats need to share components
- Tooling requires a specific format (e.g., Swagger UI needs OAS)

### Configuration / Code

**Convert RAML to OAS using AMF:**
```bash
# Using the AML Modeling Framework CLI
amf parse --in RAML --out OAS30 \
  --input api.raml \
  --output api.yaml
```

**Convert OAS to RAML:**
```bash
amf parse --in OAS30 --out RAML \
  --input openapi.yaml \
  --output api.raml
```

**Feature comparison:**
| Feature | RAML 1.0 | OAS 3.0 |
|---------|----------|---------|
| Traits / Reuse | Native (traits, resourceTypes) | Limited ($ref) |
| Type Inheritance | Full (union, inheritance) | allOf, oneOf |
| Exchange Publishing | Native | Supported |
| Tooling Ecosystem | MuleSoft-centric | Broad (Swagger, Postman) |
| Design Center | Full support | Full support |

### How It Works
1. AMF (AML Modeling Framework) handles parsing and conversion
2. Both formats are fully supported in Anypoint Design Center
3. Exchange accepts both RAML and OAS specs
4. API Manager and gateway policies work with either format

### Gotchas
- RAML traits and resource types have no direct OAS equivalent — they are inlined during conversion
- OAS discriminator patterns do not map cleanly to RAML type hierarchies
- Converted specs may need manual cleanup for readability
- Some RAML-specific annotations are lost during conversion to OAS

### Related
- [RAML Traits](../raml-traits/) — RAML-specific reuse
- [OAS3 Fragments](../oas3-fragments/) — OAS-specific reuse
