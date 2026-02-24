## EDI Processing

> EDI X12 and EDIFACT message processing — parsing, validation, transformation, and acknowledgment generation.

### When to Use

- Exchanging purchase orders (850), invoices (810), advance ship notices (856), or functional acknowledgments (997) with trading partners
- Migrating legacy EDI middleware (Sterling, Gentran, BizTalk) to MuleSoft
- Building a modern integration layer that bridges EDI-based partners with REST/JSON internal systems
- Processing EDIFACT messages for international B2B (ORDERS, INVOIC, DESADV)

### Common Transaction Sets

| X12 Code | Name | Direction | Description |
|----------|------|-----------|-------------|
| 850 | Purchase Order | Inbound | Buyer sends PO to supplier |
| 810 | Invoice | Outbound | Supplier sends invoice to buyer |
| 856 | Advance Ship Notice | Outbound | Supplier sends shipment details |
| 997 | Functional Acknowledgment | Both | Confirms receipt and syntax validity |
| 820 | Payment Order | Inbound | Buyer sends payment instructions |
| 846 | Inventory Inquiry/Advice | Outbound | Supplier sends inventory levels |
| 855 | Purchase Order Acknowledgment | Outbound | Supplier confirms/rejects PO |

| EDIFACT Code | Name | X12 Equivalent |
|--------------|------|----------------|
| ORDERS | Purchase Order | 850 |
| INVOIC | Invoice | 810 |
| DESADV | Despatch Advice | 856 |
| CONTRL | Acknowledgment | 997 |

### Configuration

#### EDI Module Config for X12

```xml
<edi:config name="EDI_X12_Config" doc:name="EDI X12 Config">
    <edi:x12-config
        interchangeIdQualifierSelf="ZZ"
        interchangeIdSelf="${edi.selfId}"
        interchangeIdQualifierPartner="ZZ"
        interchangeIdPartner="${edi.partnerId}"
        groupIdSelf="${edi.selfGroupId}"
        groupIdPartner="${edi.partnerGroupId}"
        characterEncoding="UTF-8"
        enforceConditionalRules="true"
        enforceCodeSetValidations="true"
        enforceLengthLimits="true"
        requireUniqueInterchanges="true"
        requireUniqueGroups="true"
        requireUniqueTransactionSets="true">
        <edi:schemas>
            <edi:schema value="/x12/005010/850.esl" />
            <edi:schema value="/x12/005010/810.esl" />
            <edi:schema value="/x12/005010/856.esl" />
            <edi:schema value="/x12/005010/997.esl" />
        </edi:schemas>
    </edi:x12-config>
</edi:config>
```

#### Inbound EDI Processing Flow (850 Purchase Order)

```xml
<flow name="edi-inbound-processing-flow">
    <!-- File arrives via SFTP, AS2, or MQ -->
    <sftp:listener config-ref="SFTP_Config"
        directory="${edi.inbound.dir}"
        autoDelete="false"
        moveToDirectory="${edi.processing.dir}">
        <scheduling-strategy>
            <fixed-frequency frequency="30" timeUnit="SECONDS" />
        </scheduling-strategy>
        <sftp:matcher filenamePattern="*.edi,*.x12,*.txt" />
    </sftp:listener>

    <set-variable variableName="originalFileName" value="#[attributes.fileName]" />

    <!-- Parse EDI -->
    <edi:read config-ref="EDI_X12_Config" doc:name="Parse X12" />

    <!-- Validate and check for errors -->
    <choice doc:name="Validation Check">
        <when expression="#[payload.Errors != null and sizeOf(payload.Errors) > 0]">
            <logger level="ERROR"
                message="EDI validation errors: #[payload.Errors]" />
            <flow-ref name="edi-error-handling-flow" />
        </when>
        <otherwise>
            <!-- Generate 997 Functional Acknowledgment -->
            <flow-ref name="edi-generate-997-flow" />

            <!-- Route by transaction set -->
            <choice doc:name="Route by Transaction Set">
                <when expression="#[payload.TransactionSets.v005010.'850' != null]">
                    <flow-ref name="edi-process-850-flow" />
                </when>
                <when expression="#[payload.TransactionSets.v005010.'810' != null]">
                    <flow-ref name="edi-process-810-flow" />
                </when>
            </choice>
        </otherwise>
    </choice>
</flow>
```

#### 850 Purchase Order to JSON

```xml
<sub-flow name="edi-process-850-flow">
    <ee:transform doc:name="850 to JSON">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

var po = payload.TransactionSets.v005010."850"[0]
var header = po.Detail
---
{
    transactionType: "PurchaseOrder",
    envelope: {
        interchangeControlNumber: payload.Interchange.ISA.I13,
        groupControlNumber: payload.Groups[0].GS.GroupControlNumber,
        transactionControlNumber: po.Heading.ST.TransactionSetControlNumber
    },
    purchaseOrder: {
        poNumber: po.Heading.BEG.BEG03,
        poDate: po.Heading.BEG.BEG05 as Date {format: "yyyyMMdd"} as String {format: "yyyy-MM-dd"},
        poType: po.Heading.BEG.BEG01,
        currency: (po.Heading.CUR.CUR02) default "USD",
        buyer: {
            name: (po.Heading.N1 filter ($.N101 == "BY"))[0].N102 default null,
            id: (po.Heading.N1 filter ($.N101 == "BY"))[0].N104 default null
        },
        shipTo: {
            name: (po.Heading.N1 filter ($.N101 == "ST"))[0].N102 default null,
            address: {
                street: (po.Heading.N1 filter ($.N101 == "ST"))[0].N3[0].N301 default null,
                city: (po.Heading.N1 filter ($.N101 == "ST"))[0].N4.N401 default null,
                state: (po.Heading.N1 filter ($.N101 == "ST"))[0].N4.N402 default null,
                zip: (po.Heading.N1 filter ($.N101 == "ST"))[0].N4.N403 default null
            }
        },
        lineItems: po.Detail.*PO1 map ((line, idx) -> {
            lineNumber: idx + 1,
            quantity: line.PO102 as Number,
            unitOfMeasure: line.PO103,
            unitPrice: line.PO104 as Number,
            productId: line.PO107,
            productIdQualifier: line.PO106,
            description: (line.PID[0].PID05) default null
        }),
        summary: {
            totalLineItems: po.Summary.CTT.CTT01 as Number default sizeOf(po.Detail.*PO1),
            totalAmount: po.Summary.CTT.CTT02 as Number default null
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Send to order management system -->
    <http:request config-ref="OMS_API"
        method="POST"
        path="/api/orders" />
</sub-flow>
```

#### Generate 997 Functional Acknowledgment

```xml
<sub-flow name="edi-generate-997-flow">
    <ee:transform doc:name="Build 997">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java

var isa = payload.Interchange.ISA
var gs = payload.Groups[0].GS
---
{
    TransactionSets: {
        v005010: {
            "997": [{
                Heading: {
                    ST: {
                        TransactionSetIdentifierCode: "997",
                        TransactionSetControlNumber: "0001"
                    },
                    AK1: {
                        FunctionalIdentifierCode: gs.FunctionalIdentifierCode,
                        GroupControlNumber: gs.GroupControlNumber
                    }
                },
                Detail: {
                    AK2_Loop: payload.Groups[0].TransactionSets map ((ts) -> {
                        AK2: {
                            TransactionSetIdentifierCode: ts.ST.TransactionSetIdentifierCode,
                            TransactionSetControlNumber: ts.ST.TransactionSetControlNumber
                        },
                        AK5: {
                            TransactionSetAcknowledgmentCode: "A"  // A=Accepted
                        }
                    })
                },
                Summary: {
                    AK9: {
                        FunctionalGroupAcknowledgeCode: "A",
                        NumberOfTransactionSetsIncluded: sizeOf(payload.Groups[0].TransactionSets),
                        NumberOfReceivedTransactionSets: sizeOf(payload.Groups[0].TransactionSets),
                        NumberOfAcceptedTransactionSets: sizeOf(payload.Groups[0].TransactionSets)
                    },
                    SE: {
                        NumberOfIncludedSegments: "0",
                        TransactionSetControlNumber: "0001"
                    }
                }
            }]
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <edi:write config-ref="EDI_X12_Config" doc:name="Write 997" />

    <!-- Send 997 back to partner -->
    <sftp:write config-ref="SFTP_Partner_Config"
        path="#[vars.partner997Dir ++ '/997_' ++ now() as String {format: 'yyyyMMddHHmmss'} ++ '.edi']" />
</sub-flow>
```

#### Outbound 810 Invoice Generation

```dataweave
%dw 2.0
output application/java

var invoice = payload
---
{
    TransactionSets: {
        v005010: {
            "810": [{
                Heading: {
                    ST: {
                        TransactionSetIdentifierCode: "810",
                        TransactionSetControlNumber: vars.controlNumber
                    },
                    BIG: {
                        BIG01: invoice.invoiceDate as String {format: "yyyyMMdd"},
                        BIG02: invoice.invoiceNumber,
                        BIG03: invoice.poDate as String {format: "yyyyMMdd"},
                        BIG04: invoice.poNumber
                    },
                    N1: [
                        {
                            N101: "RE",  // Remit-to
                            N102: invoice.seller.name,
                            N103: "91",
                            N104: invoice.seller.id
                        },
                        {
                            N101: "BT",  // Bill-to
                            N102: invoice.buyer.name,
                            N103: "91",
                            N104: invoice.buyer.id
                        }
                    ]
                },
                Detail: {
                    IT1: invoice.lineItems map ((item, idx) -> {
                        IT101: (idx + 1) as String,
                        IT102: item.quantity,
                        IT103: item.unitOfMeasure,
                        IT104: item.unitPrice,
                        IT106: "VP",
                        IT107: item.vendorPartNumber
                    })
                },
                Summary: {
                    TDS: {
                        TDS01: (invoice.totalAmount * 100) as String {format: "0"}
                    },
                    CTT: {
                        CTT01: sizeOf(invoice.lineItems)
                    },
                    SE: {
                        NumberOfIncludedSegments: "0",
                        TransactionSetControlNumber: vars.controlNumber
                    }
                }
            }]
        }
    }
}
```

### How It Works

1. **File reception** — EDI files arrive via SFTP, AS2, or message queue. The SFTP listener picks up files matching `.edi`, `.x12`, or `.txt` extensions
2. **EDI parsing** — The `edi:read` operation parses the raw EDI text into a structured MuleSoft object using the configured schema (`.esl` files) for the target X12 version
3. **Envelope validation** — The parser validates ISA/GS envelopes, checking interchange and group control numbers for uniqueness and correct formatting
4. **Transaction routing** — The parsed payload is routed by transaction set identifier (850, 810, 856) to the appropriate processing sub-flow
5. **DataWeave transformation** — EDI's positional segment/element structure is mapped to JSON for downstream REST/JSON systems
6. **997 generation** — A functional acknowledgment (997) is generated and sent back to the trading partner confirming receipt and validation status
7. **Outbound generation** — For sending EDI, JSON is transformed into the EDI segment structure, then `edi:write` serializes it back to raw EDI text

### Gotchas

- **Partner-specific customizations** — Trading partners frequently deviate from the X12 standard. One partner may put the PO number in BEG03 while another uses a REF segment. Maintain per-partner DataWeave mapping modules and use a partner lookup to select the correct one
- **Segment terminator issues** — The default segment terminator is `~` and element separator is `*`, but some partners use custom delimiters (e.g., `\n` as segment terminator). Check the ISA segment's last characters to detect the actual delimiters. The EDI module handles this automatically, but custom parsers do not
- **ISA/GS envelope validation** — Duplicate interchange control numbers are rejected when `requireUniqueInterchanges="true"`. Partners that reuse control numbers (common in testing) will cause failures. Disable uniqueness checks for non-production environments
- **Schema version mismatches** — An 850 from version 4010 has different segment structures than version 5010. Always confirm the X12 version with your trading partner and load the matching `.esl` schema
- **Character encoding** — EDI traditionally uses ASCII. International partners using EDIFACT may send UTF-8 or ISO-8859-1. Set `characterEncoding` explicitly in the EDI config to match your partners
- **Empty optional segments** — Some partners omit optional segments entirely; others send them empty. DataWeave null-safe navigation (`?.` and `default`) is essential when mapping EDI segments that may not exist
- **Control number management** — Outbound EDI requires incrementing ISA, GS, and ST control numbers. Use Object Store to persist the last-used number and increment atomically. Gaps are acceptable; duplicates are not

### Related

- [AS2 Exchange](../as2-exchange/) — Transport protocol commonly used to deliver EDI files with receipt confirmation
- [SFTP Guaranteed Delivery](../sftp-guaranteed-delivery/) — Alternative transport for EDI files when AS2 is not available
- [SAP IDoc Processing](../sap-idoc-processing/) — Similar document-based integration for SAP-specific formats
