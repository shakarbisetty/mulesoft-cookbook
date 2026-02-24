## Bulk Per-Record Validation
> Validate an array of records, skip invalid ones, process valid ones, return per-record results.

### When to Use
- Bulk import APIs where some records may be invalid
- You want to process valid records and report invalid ones
- Partial success is acceptable (not all-or-nothing)

### Configuration / Code

```xml
<flow name="bulk-import-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/bulk-import" method="POST"/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload.records map ((record, index) -> {
    index: index,
    record: record,
    errors: []
        ++ (if (record.email == null) [{field: "email", message: "Required"}] else [])
        ++ (if (record.name == null) [{field: "name", message: "Required"}] else [])
        ++ (if (record.email != null and !(record.email matches /^.+@.+\..+$/)) [{field: "email", message: "Invalid format"}] else [])
})]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="validRecords" value="#[payload filter isEmpty($.errors)]"/>
    <set-variable variableName="invalidRecords" value="#[payload filter !isEmpty($.errors)]"/>

    <!-- Process valid records -->
    <foreach collection="#[vars.validRecords]">
        <flow-ref name="upsert-record"/>
    </foreach>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    total: sizeOf(vars.validRecords) + sizeOf(vars.invalidRecords),
    accepted: sizeOf(vars.validRecords),
    rejected: sizeOf(vars.invalidRecords),
    errors: vars.invalidRecords map {
        index: $.index,
        record: $.record,
        violations: $.errors
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
    <set-variable variableName="httpStatus" value="#[if (sizeOf(vars.invalidRecords) > 0) '207' else '200']"/>
</flow>
```

### How It Works
1. DataWeave validates each record and attaches an `errors` array
2. Records are partitioned into valid and invalid sets
3. Only valid records are processed
4. Response includes counts and per-record error details
5. HTTP 207 Multi-Status if there are mixed results

### Gotchas
- Validate ALL records before processing any — partial commits without validation are dangerous
- Large arrays may need streaming/batch processing instead of in-memory validation
- Return 207 (not 200 or 400) for mixed results — clients need to check per-record status

### Related
- [Partial Success 207](../../recovery/partial-success-207/) — HTTP 207 pattern
- [Custom Business Validation](../custom-business-validation/) — single-record validation
