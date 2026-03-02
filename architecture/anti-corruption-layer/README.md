## Anti-Corruption Layer
> Legacy system isolation with data translation boundaries in MuleSoft

### When to Use
- You are integrating with a legacy system whose data model pollutes your modern domain
- Field names, data formats, or business rules from the old system leak into new APIs
- Multiple teams consume the same legacy system and each builds their own translation logic
- You are planning a system migration and need to isolate the blast radius

### The Problem

Legacy systems export data in formats that reflect decades-old design decisions: cryptic field names (CUST_NM, ORD_AMT_01), packed data formats (YYYYMMDD strings, cents-as-integers), and domain concepts that no longer match the business. When modern APIs directly consume these formats, the legacy model infects the entire integration layer.

An anti-corruption layer (ACL) is a dedicated translation boundary that converts legacy concepts into your modern domain model. In MuleSoft, this is typically a system API or a dedicated adapter flow that shields the rest of your integration from legacy data structures.

### Configuration / Code

#### ACL Architecture

```
WITHOUT ACL:
  ┌──────────┐     ┌──────────┐     ┌──────────┐
  │ Modern   │     │ Process  │     │ Legacy   │
  │ Consumer │────►│ API      │────►│ System   │
  └──────────┘     └──────────┘     └──────────┘
       │                │                │
       │  Legacy field names, formats,   │
       │  and concepts leak through      │
       │  every layer                    │
       └─────── CORRUPTION ──────────────┘

WITH ACL:
  ┌──────────┐     ┌──────────┐     ┌─────────────┐     ┌──────────┐
  │ Modern   │     │ Process  │     │ ACL         │     │ Legacy   │
  │ Consumer │────►│ API      │────►│ (System API)│────►│ System   │
  └──────────┘     └──────────┘     └─────────────┘     └──────────┘
       │                │                │                    │
       │  Clean domain  │  Clean domain  │  Legacy formats   │
       │  model         │  model         │  translated here  │
       │                │                │  and ONLY here    │
       └─── CLEAN ──────┴─── CLEAN ──────┘                   │
                                         └── CONTAINMENT ────┘
```

#### Legacy System: Mainframe COBOL Copybook Response

```
Typical legacy response (fixed-width or packed):
  CUST_NM:          SMITH JOHN A
  CUST_ACCT_NO:     00042719384
  CUST_STAT_CD:     A
  ORD_DT:           20260228
  ORD_AMT_01:       0000125099    (meaning $1,250.99 — cents, zero-padded)
  ORD_TYP_CD:       R             (meaning "Regular" — undocumented code)
  SHIP_METH_CD:     02            (meaning "Ground" — undocumented code)
  DLV_ADDR_LN1:     123 MAIN ST
  DLV_ADDR_LN2:
  DLV_CTY_NM:       SPRINGFIELD
  DLV_ST_CD:        IL
  DLV_ZIP_CD:       62701
```

#### ACL Translation (System API)

```xml
<!-- ACL: translates legacy response to clean domain model -->
<flow name="acl-get-customer-order">
    <http:listener config-ref="HTTPS_Listener"
                   path="/api/customers/{customerId}/orders/{orderId}" />

    <!-- Call legacy system — the ACL knows how to talk to it -->
    <http:request config-ref="Mainframe_Gateway"
                 path="/CICS/ORDINQ"
                 method="POST">
        <http:body>#[%dw 2.0
output application/json
---
{
    "CUST_ACCT_NO": attributes.uriParams.customerId,
    "ORD_SEQ_NO": attributes.uriParams.orderId
}]</http:body>
    </http:request>

    <!-- ACL translation: legacy → modern domain model -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

// Code tables — the ACL owns this translation knowledge
var orderTypes = {
    "R": "REGULAR",
    "E": "EXPRESS",
    "B": "BACKORDER",
    "X": "CANCELLED"
}

var shippingMethods = {
    "01": "OVERNIGHT",
    "02": "GROUND",
    "03": "TWO_DAY",
    "04": "FREIGHT"
}

var statusCodes = {
    "A": "ACTIVE",
    "I": "INACTIVE",
    "S": "SUSPENDED",
    "C": "CLOSED"
}

---
{
    customer: {
        id: trim(payload.CUST_ACCT_NO),
        name: {
            // Parse "SMITH JOHN A" into structured name
            last: trim(payload.CUST_NM) splitBy " " then $[0],
            first: trim(payload.CUST_NM) splitBy " " then $[1],
            middle: trim(payload.CUST_NM) splitBy " " then $[2] default null
        },
        status: statusCodes[payload.CUST_STAT_CD] default "UNKNOWN"
    },
    order: {
        id: trim(payload.ORD_SEQ_NO),
        date: payload.ORD_DT as Date { format: "yyyyMMdd" }
              as String { format: "yyyy-MM-dd" },
        type: orderTypes[payload.ORD_TYP_CD] default "UNKNOWN",
        total: {
            // Convert cents-as-integer to decimal
            amount: (payload.ORD_AMT_01 as Number) / 100,
            currency: "USD"
        },
        shipping: {
            method: shippingMethods[payload.SHIP_METH_CD] default "UNKNOWN",
            address: {
                line1: trim(payload.DLV_ADDR_LN1),
                line2: if (trim(payload.DLV_ADDR_LN2) != "")
                          trim(payload.DLV_ADDR_LN2)
                       else null,
                city: trim(payload.DLV_CTY_NM),
                state: trim(payload.DLV_ST_CD),
                postalCode: trim(payload.DLV_ZIP_CD),
                country: "US"
            }
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Bidirectional ACL (Write Path)

```xml
<!-- ACL: translate modern domain model back to legacy format for writes -->
<flow name="acl-create-order">
    <http:listener config-ref="HTTPS_Listener"
                   path="/api/orders" method="POST" />

    <!-- Translate clean domain model → legacy format -->
    <ee:transform>
        <ee:message>
            <ee:set-variable variableName="legacyPayload"><![CDATA[%dw 2.0
output application/json

var reverseOrderTypes = {
    "REGULAR": "R",
    "EXPRESS": "E",
    "BACKORDER": "B"
}

var reverseShippingMethods = {
    "OVERNIGHT": "01",
    "GROUND": "02",
    "TWO_DAY": "03",
    "FREIGHT": "04"
}

fun padLeft(value, length, char = "0") =
    if (sizeOf(value as String) >= length) value as String
    else (char * (length - sizeOf(value as String))) ++ (value as String)

---
{
    "CUST_ACCT_NO": padLeft(payload.customer.id, 11),
    "ORD_DT": now() as String { format: "yyyyMMdd" },
    "ORD_TYP_CD": reverseOrderTypes[payload.order.type] default "R",
    "ORD_AMT_01": padLeft(
        (payload.order.total.amount * 100) as String { format: "0" },
        10
    ),
    "SHIP_METH_CD": reverseShippingMethods[payload.order.shipping.method]
                    default "02",
    "DLV_ADDR_LN1": upper(payload.order.shipping.address.line1),
    "DLV_ADDR_LN2": upper(payload.order.shipping.address.line2 default ""),
    "DLV_CTY_NM": upper(payload.order.shipping.address.city),
    "DLV_ST_CD": upper(payload.order.shipping.address.state),
    "DLV_ZIP_CD": payload.order.shipping.address.postalCode
}]]></ee:set-variable>
        </ee:message>
    </ee:transform>

    <!-- Send to legacy system -->
    <http:request config-ref="Mainframe_Gateway" path="/CICS/ORDCRT" method="POST">
        <http:body>#[vars.legacyPayload]</http:body>
    </http:request>
</flow>
```

#### ACL Responsibilities Checklist

| Responsibility | What It Means |
|---------------|---------------|
| **Field mapping** | Legacy field names → domain field names |
| **Type conversion** | Strings → dates, cents → decimals, codes → enums |
| **Code table resolution** | Single-char codes → human-readable values |
| **Null handling** | Spaces/zeros → null, empty strings → null |
| **Error translation** | Legacy error codes → HTTP status codes + domain errors |
| **Protocol adaptation** | SOAP/MQ/fixed-width → REST/JSON |
| **Character encoding** | EBCDIC → UTF-8, padding → trimmed strings |
| **Business rule shielding** | Legacy validation quirks stay in the ACL |

#### What Does NOT Belong in the ACL

| Should Not Be Here | Where It Belongs |
|-------------------|-----------------|
| Business orchestration | Process API |
| Consumer-specific formatting | Experience API |
| Caching | Separate caching layer or the ACL can cache, but caching is not its primary concern |
| Authentication/authorization | API Manager policies |

### How It Works

1. **Map the legacy interface** — document every field, code table, and format quirk
2. **Define your clean domain model** — what the data SHOULD look like in your modern architecture
3. **Build the ACL as a system API** — one ACL per legacy system, not per consumer
4. **Test with real legacy data** — edge cases in legacy systems are brutal (null as spaces, dates as 00000000, negative amounts as letters)
5. **Share the ACL across all consumers** — process APIs call the ACL, not the legacy system directly

### Gotchas

- **The ACL is not a pass-through with renaming.** Renaming `CUST_NM` to `customerName` without parsing the structured name is half-hearted. Translate fully into your domain model.
- **Code tables must be maintained.** When the legacy system adds a new status code, the ACL must be updated. Externalize code tables into properties files or a config table, not hardcoded in DataWeave.
- **Legacy error responses are rarely standardized.** The same system might return errors as HTTP 200 with an error field, HTTP 500 with HTML, or a SOAP fault. The ACL must handle all variants.
- **Performance: the ACL adds a hop.** If the legacy system is on-prem and the ACL is on CloudHub, you pay VPN latency twice (in and out). Consider deploying the ACL on RTF co-located with the legacy system.
- **One ACL per legacy system, not per domain entity.** A single `sys-mainframe-acl` API handles all mainframe interactions (orders, customers, inventory). Do not create separate ACLs for each entity unless the mainframe is actually separate systems.

### Related

- [Hexagonal Architecture](../hexagonal-architecture-mulesoft/) — ACL as an outbound adapter
- [Strangler Fig Migration](../strangler-fig-migration/) — ACL enables incremental legacy replacement
- [API Versioning Strategy](../api-versioning-strategy/) — ACL as a versioning boundary
- [Domain-Driven API Design](../domain-driven-api-design/) — ACL protects bounded context boundaries
