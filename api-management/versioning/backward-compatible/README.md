## Backward-Compatible API Changes
> Make additive changes to APIs without breaking existing clients.

### When to Use
- Adding new fields or endpoints without a major version bump
- Evolving APIs without forcing client updates
- Minimizing version proliferation

### Configuration / Code

**Safe additive changes (no version bump needed):**
```yaml
# v1.0 - Original
Order:
  properties:
    id: string
    total: number

# v1.1 - Added optional fields (backward compatible)
Order:
  properties:
    id: string
    total: number
    currency:          # NEW - optional, has default
      type: string
      default: "USD"
    discountApplied:   # NEW - optional
      type: boolean
```

**Mule 4 — tolerant parsing:**
```xml
<ee:transform>
    <ee:message>
        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    id: payload.id,
    total: payload.total,
    // New field with fallback for old clients
    currency: payload.currency default "USD"
}]]></ee:set-payload>
    </ee:message>
</ee:transform>
```

### How It Works
1. **Add optional fields** — old clients ignore them, new clients use them
2. **Add new endpoints** — old clients do not call them, no breakage
3. **Add new enum values** — old clients may see unknown values (handle gracefully)
4. **Widen input types** — accept more formats (string → string|number)

### Gotchas
- Removing fields is ALWAYS a breaking change — use deprecation
- Changing field types (string → number) is breaking
- Making optional fields required is breaking
- Renaming fields is breaking — add the new name, deprecate the old one

### Related
- [Deprecation Sunset](../deprecation-sunset/) — retiring old behavior
- [URL Path Versioning](../url-path-versioning/) — when breaking changes are needed
