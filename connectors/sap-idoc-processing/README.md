## SAP IDoc Processing

> Inbound and outbound IDoc processing via the MuleSoft SAP connector with DataWeave transformation to JSON.

### When to Use

- Receiving master data or transactional documents from SAP (inbound IDocs)
- Sending purchase orders, invoices, or confirmations back to SAP (outbound IDocs)
- Integrating SAP with cloud applications that expect JSON/REST
- Replacing legacy PI/PO middleware with MuleSoft for SAP-to-any connectivity

### Common IDoc Types

| IDoc Type | Description | Direction | Use Case |
|-----------|-------------|-----------|----------|
| MATMAS | Material Master | Outbound from SAP | Sync product catalog to e-commerce |
| DEBMAS | Customer Master | Outbound from SAP | Sync customers to CRM |
| ORDERS | Purchase Order | Inbound to SAP | Create POs from procurement apps |
| INVOIC | Invoice | Both | Invoice exchange between systems |
| DESADV | Delivery Notification | Outbound from SAP | Ship confirm to logistics |
| WMMBID | Goods Movement | Outbound from SAP | Inventory sync to WMS |

### Configuration

#### SAP Connector Global Config

```xml
<sap:config name="SAP_Config" doc:name="SAP Config">
    <sap:simple-connection-provider
        applicationServerHost="${sap.host}"
        username="${sap.username}"
        password="${sap.password}"
        systemNumber="${sap.systemNumber}"
        client="${sap.client}"
        language="EN" />
</sap:config>
```

#### Inbound IDoc Listener

```xml
<flow name="sap-idoc-inbound-flow">
    <sap:document-listener
        doc:name="IDoc Listener"
        config-ref="SAP_Config"
        gatewayHost="${sap.gwHost}"
        gatewayService="${sap.gwService}"
        programId="${sap.programId}"
        connectionCount="2"
        operationTimeout="60000" />

    <logger level="INFO"
        message="Received IDoc: #[payload.IDOC.EDI_DC40.IDOCTYP] - #[payload.IDOC.EDI_DC40.DOCNUM]" />

    <choice doc:name="Route by IDoc Type">
        <when expression="#[payload.IDOC.EDI_DC40.IDOCTYP == 'MATMAS05']">
            <flow-ref name="process-matmas-flow" />
        </when>
        <when expression="#[payload.IDOC.EDI_DC40.IDOCTYP == 'DEBMAS07']">
            <flow-ref name="process-debmas-flow" />
        </when>
        <otherwise>
            <flow-ref name="process-generic-idoc-flow" />
        </otherwise>
    </choice>

    <error-handler>
        <on-error-propagate type="SAP:CONNECTIVITY">
            <logger level="ERROR" message="SAP connection lost: #[error.description]" />
        </on-error-propagate>
        <on-error-continue type="ANY">
            <logger level="ERROR"
                message="IDoc processing error: #[error.description]" />
            <flow-ref name="dead-letter-queue-flow" />
        </on-error-continue>
    </error-handler>
</flow>
```

#### Outbound IDoc Send

```xml
<flow name="sap-idoc-outbound-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/sap/orders"
        allowedMethods="POST" />

    <ee:transform doc:name="JSON to ORDERS IDoc">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/xml
---
{
    ORDERS05: {
        IDOC: {
            EDI_DC40: {
                IDOCTYP: "ORDERS05",
                MESTYP: "ORDERS",
                SNDPOR: "MULESOFT",
                SNDPRT: "LS",
                SNDPRN: vars.senderPartner,
                RCVPOR: "SAPPR1",
                RCVPRT: "LS",
                RCVPRN: vars.receiverPartner
            },
            E1EDK01: {
                CURCY: payload.currency,
                WKURS: "1.00000",
                ZTERM: payload.paymentTerms
            },
            (payload.lineItems map ((item, idx) -> {
                E1EDP01: {
                    POSEX: idx + 1 as String {format: "000000"},
                    MENGE: item.quantity,
                    MENEE: item.unit,
                    E1EDP19: {
                        QUALF: "002",
                        IDTNR: item.materialNumber
                    }
                }
            }))
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <sap:send config-ref="SAP_Config"
        doc:name="Send IDoc"
        key="ORDERS05"
        type="idoc" />

    <ee:transform doc:name="Build Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "sent",
    idocNumber: payload.DOCNUM,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### DataWeave: IDoc XML to JSON

```dataweave
%dw 2.0
output application/json
var idoc = payload.MATMAS05.IDOC
var header = idoc.EDI_DC40
var materialData = idoc.E1MARAM
---
{
    idocNumber: header.DOCNUM,
    idocType: header.IDOCTYP,
    messageType: header.MESTYP,
    createdAt: header.CREDAT ++ "T" ++ header.CRETIM,
    material: {
        number: materialData.MATNR,
        type: materialData.MTART,
        group: materialData.MATKL,
        baseUnit: materialData.MEINS,
        grossWeight: materialData.BRGEW as Number default 0,
        weightUnit: materialData.GEWEI,
        descriptions: materialData.*E1MAKTM map {
            language: $.SPRAS,
            text: $.MAKTX
        },
        plants: materialData.*E1MARCM map {
            plantCode: $.WERKS,
            mrpType: $.DISMM,
            mrpController: $.DISPO,
            lotSize: $.DISLS,
            safetyStock: $.EISBE as Number default 0
        },
        salesOrgs: materialData.*E1MVKEM map {
            salesOrg: $.VKORG,
            distributionChannel: $.VTWEG,
            itemCategory: $.MTPOS
        }
    }
}
```

### How It Works

1. **Register Program ID** — The SAP system is configured with an RFC destination pointing to the MuleSoft listener's program ID and gateway
2. **IDoc Listener starts** — MuleSoft registers with the SAP gateway and waits for inbound IDocs over the tRFC protocol
3. **IDoc arrives** — SAP sends the IDoc document; MuleSoft receives the full XML structure including control record (EDI_DC40) and data segments
4. **Route by type** — A choice router inspects `EDI_DC40.IDOCTYP` to dispatch to the correct processing sub-flow
5. **Transform** — DataWeave maps the IDoc's nested segment hierarchy into flat JSON for downstream REST/JSON consumers
6. **Outbound flow** — For sending IDocs back to SAP, the reverse DataWeave mapping builds the IDoc XML structure from JSON input, then sends via the SAP connector

### Gotchas

- **SAP JCo library licensing** — The SAP Java Connector (JCo) libraries (`sapjco3.jar` and native `.dll`/`.so`) are not included in the MuleSoft connector. You must download them from SAP Service Marketplace with a valid S-user license and place them in `${MULE_HOME}/lib/user`
- **RFC destination configuration** — The SAP RFC destination must be type "T" (TCP/IP) with activation type "Registered Server Program". Mismatching the program ID between SAP and MuleSoft is the most common setup failure
- **Character encoding** — SAP uses its own character encoding internally. Set `jcoClient.unicode=1` in connector properties to avoid garbled special characters. Non-Latin scripts (CJK, Cyrillic) require explicit codepage configuration
- **IDoc segment versioning** — IDoc types have version suffixes (e.g., MATMAS05 vs MATMAS01). Always match the exact version configured in your SAP partner profile
- **Transaction handling** — IDoc listeners use tRFC (transactional RFC). If your flow fails after MuleSoft acknowledges receipt, the IDoc shows "dispatched" in SAP but never processed. Implement idempotent processing or use Object Store to track processed DOCNUM values
- **Connection pooling** — Set `connectionCount` appropriately. Too few connections cause queuing under load; too many exhaust SAP dialog processes

### Related

- [Database CDC](../database-cdc/) — For polling-based data sync as an alternative to IDoc push
- [EDI Processing](../edi-processing/) — Similar document-based integration for non-SAP B2B partners
- [SFTP Guaranteed Delivery](../sftp-guaranteed-delivery/) — For SAP file-based interfaces (ABAP `OPEN DATASET`)
