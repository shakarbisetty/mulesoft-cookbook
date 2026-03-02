## SAP IDoc Processing Complete

> End-to-end IDoc processing with TID handler, error recovery, ALE monitoring, and segment-level mapping for Mule 4 SAP connector.

### When to Use

- Building a production-grade SAP IDoc integration that needs TID (Transaction ID) management for exactly-once delivery
- Receiving inbound IDocs from SAP (e.g., MATMAS, DEBMAS, ORDERS) and transforming them for downstream systems
- Sending outbound IDocs to SAP with proper acknowledgment handling
- Need error recovery that does not lose IDocs when Mule or SAP is temporarily unavailable

### The Problem

The basic SAP IDoc tutorial covers happy-path send/receive, but production integrations fail on TID handling, segment-level error recovery, and ALE monitoring. Without a TID handler, SAP retries create duplicate IDocs. Without segment-level error handling, a single bad segment rejects the entire IDoc. Without ALE status updates, SAP admins have no visibility into processing status.

### Configuration

#### SAP Connector with TID Handler

```xml
<sap:config name="SAP_Config" doc:name="SAP Config">
    <sap:simple-connection-provider
        applicationServerHost="${sap.host}"
        systemNumber="${sap.systemNumber}"
        client="${sap.client}"
        userName="${sap.user}"
        password="${sap.password}"
        language="EN" />
</sap:config>

<os:object-store name="SAP_TID_Store"
    doc:name="SAP TID Store"
    persistent="true"
    entryTtl="7"
    entryTtlUnit="DAYS"
    maxEntries="50000" />
```

#### Inbound IDoc Receiver with TID Management

```xml
<flow name="sap-idoc-inbound-receiver-flow">
    <sap:document-listener config-ref="SAP_Config"
        doc:name="IDoc Listener"
        gatewayHost="${sap.gwHost}"
        gatewayService="${sap.gwService}"
        programId="${sap.programId}"
        connectionCount="2"
        operationTimeout="60"
        operationTimeoutUnit="SECONDS" />

    <!-- TID deduplication -->
    <set-variable variableName="sapTid"
        value="#[attributes.transactionId]" />

    <try doc:name="TID Check">
        <os:contains key="#[vars.sapTid]"
            objectStore="SAP_TID_Store"
            doc:name="Check TID Exists" />

        <choice doc:name="Duplicate?">
            <when expression="#[payload == true]">
                <logger level="WARN"
                    message="Duplicate IDoc TID detected: #[vars.sapTid]. Acknowledging without reprocessing." />
                <!-- Return success to SAP to stop retries -->
                <set-payload value="#['OK']" />
            </when>
            <otherwise>
                <!-- Store TID before processing -->
                <os:store key="#[vars.sapTid]"
                    objectStore="SAP_TID_Store"
                    doc:name="Store TID">
                    <os:value><![CDATA[#[{
                        receivedAt: now() as String,
                        idocNumber: payload.IDOC.EDI_DC40.DOCNUM default 'unknown',
                        idocType: payload.IDOC.EDI_DC40.IDOCTYP default 'unknown',
                        status: 'PROCESSING'
                    } as String]]]></os:value>
                </os:store>

                <!-- Process the IDoc -->
                <flow-ref name="sap-idoc-process-subflow" />

                <!-- Update TID status to COMPLETED -->
                <os:store key="#[vars.sapTid]"
                    objectStore="SAP_TID_Store"
                    doc:name="Update TID Status">
                    <os:value><![CDATA[#[{
                        receivedAt: now() as String,
                        status: 'COMPLETED'
                    } as String]]]></os:value>
                </os:store>
            </otherwise>
        </choice>

        <error-handler>
            <on-error-continue type="ANY">
                <logger level="ERROR"
                    message="IDoc processing failed for TID #[vars.sapTid]: #[error.description]" />
                <!-- Store as FAILED for retry -->
                <os:store key="#['FAILED_' ++ vars.sapTid]"
                    objectStore="SAP_TID_Store">
                    <os:value><![CDATA[#[{
                        failedAt: now() as String,
                        error: error.description,
                        payload: write(payload, 'application/xml')
                    } as String]]]></os:value>
                </os:store>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

#### IDoc Segment-Level Processing

```xml
<sub-flow name="sap-idoc-process-subflow">
    <ee:transform doc:name="Parse IDoc Segments">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var controlRecord = payload.IDOC.EDI_DC40
var dataSegments = payload.IDOC.E1MARAM
---
{
    controlInfo: {
        idocNumber: controlRecord.DOCNUM,
        idocType: controlRecord.IDOCTYP,
        mesType: controlRecord.MESTYP,
        senderPartner: controlRecord.SNDPRN,
        senderPort: controlRecord.SNDPOR,
        receiverPartner: controlRecord.RCVPRN,
        createdOn: controlRecord.CREDAT,
        createdAt: controlRecord.CRETIM
    },
    materials: dataSegments map ((segment) -> {
        materialNumber: trim(segment.MATNR),
        materialType: segment.MTART,
        industryKey: segment.MBRSH,
        materialGroup: segment.MATKL,
        baseUom: segment.MEINS,
        grossWeight: segment.BRGEW as Number default 0,
        netWeight: segment.NTGEW as Number default 0,
        weightUnit: segment.GEWEI,
        descriptions: (segment.E1MAKTM default []) map {
            language: $.SPRAS,
            text: trim($.MAKTX)
        },
        plants: (segment.E1MARCM default []) map {
            plantCode: $.WERKS,
            mrpType: $.DISMM,
            mrpController: $.DISPO,
            lotSize: $.DISLS
        },
        salesOrg: (segment.E1MVKEM default []) map {
            salesOrg: $.VKORG,
            distChannel: $.VTWEG,
            division: $.SPART
        }
    })
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="idocData" value="#[payload]" />

    <!-- Process each material -->
    <foreach doc:name="Process Materials"
        collection="#[payload.materials]">
        <try doc:name="Process Single Material">
            <http:request config-ref="MDM_API_Config"
                method="PUT"
                path="/api/materials/#[payload.materialNumber]" />

            <error-handler>
                <on-error-continue type="ANY">
                    <logger level="ERROR"
                        message="Failed to process material #[payload.materialNumber]: #[error.description]" />
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>
</sub-flow>
```

#### Outbound IDoc — Send to SAP

```xml
<flow name="sap-idoc-outbound-send-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/sap/orders"
        allowedMethods="POST" />

    <ee:transform doc:name="Build ORDERS05 IDoc">
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
                SNDPRN: "MULE_PARTNER",
                RCVPOR: "SAPPORT",
                RCVPRT: "LS",
                RCVPRN: "SAP_SYSTEM"
            },
            E1EDK01: {
                ACTION: "009",
                CURCY: payload.currency default "USD",
                WKURS: "1.00000",
                ZTERM: payload.paymentTerms default "NT30",
                E1EDK14: [
                    { QUESSION: "001", ORGAN: payload.salesOrg },
                    { QUESSION: "002", ORGAN: payload.distChannel },
                    { QUESSION: "003", ORGAN: payload.division }
                ],
                E1EDK02: {
                    QUESSION: "001",
                    BELNR: payload.orderNumber
                }
            },
            (payload.lineItems map ((item, idx) -> {
                E1EDP01: {
                    POSEX: (idx + 1) as String {format: "000000"},
                    MENGE: item.quantity as String,
                    MENEE: item.uom default "EA",
                    E1EDP19: {
                        QUESSION: "002",
                        IDNKD: item.materialNumber
                    }
                }
            }))
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <sap:send config-ref="SAP_Config"
        doc:name="Send IDoc to SAP"
        key="ORDERS05"
        operationType="idoc" />

    <ee:transform doc:name="Confirmation Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "sent",
    idocType: "ORDERS05",
    sapTid: attributes.transactionId default "N/A",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Failed IDoc Retry Flow

```xml
<flow name="sap-idoc-retry-failed-flow">
    <scheduler doc:name="Retry Every 15 Minutes">
        <scheduling-strategy>
            <fixed-frequency frequency="15" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <os:retrieve-all objectStore="SAP_TID_Store"
        doc:name="Get All TIDs" />

    <ee:transform doc:name="Filter Failed TIDs">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
---
payload filterObject ((value, key) ->
    (key as String) startsWith "FAILED_"
) pluck ((value, key) -> {
    tid: (key as String) replace "FAILED_" with "",
    details: read(value, "application/json")
})]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <foreach doc:name="Retry Each Failed IDoc"
        collection="#[payload]">
        <try doc:name="Retry Processing">
            <set-payload value="#[read(payload.details.payload, 'application/xml')]" />
            <flow-ref name="sap-idoc-process-subflow" />

            <!-- Remove failed marker on success -->
            <os:remove key="#['FAILED_' ++ payload.tid]"
                objectStore="SAP_TID_Store" />
            <os:store key="#[payload.tid]"
                objectStore="SAP_TID_Store">
                <os:value>COMPLETED</os:value>
            </os:store>

            <error-handler>
                <on-error-continue type="ANY">
                    <logger level="WARN"
                        message="Retry still failing for TID #[payload.tid]: #[error.description]" />
                </on-error-continue>
            </error-handler>
        </try>
    </foreach>
</flow>
```

### Gotchas

- **TID handler is mandatory for production** — Without TID tracking, SAP will retry IDocs on any communication failure, creating duplicate records in your target system. The Object Store approach above is simpler than implementing `SapJCoServerTidHandler` directly
- **`connectionCount` on the listener** — This controls how many parallel IDoc conversations SAP can open. Set it to 2-4 for most integrations. Setting it to 1 creates a bottleneck; setting it too high can overwhelm your Mule worker
- **Program ID must match SM59** — The `programId` in MuleSoft must exactly match the RFC Destination (type T) configured in SAP transaction SM59. Mismatches cause silent connection failures
- **IDoc segment names are version-specific** — `E1MARAM` is the segment name for MATMAS05. If SAP sends MATMAS03, the segment is `E1MARAM1`. Always verify the IDoc type version in WE60
- **Mandatory SAP transactions for troubleshooting** — WE02/WE05 (IDoc monitoring), BD87 (ALE status), SM58 (tRFC monitoring), SM59 (RFC destinations), WE19 (IDoc test tool)
- **Character encoding** — SAP sends IDocs in the system's codepage (often ISO-8859-1). If your target system expects UTF-8, add explicit encoding conversion. Special characters in material descriptions are a common failure point

### Testing

```xml
<munit:test name="sap-idoc-inbound-dedup-test"
    description="Verify duplicate TID is rejected">

    <munit:behavior>
        <munit-tools:mock-when processor="os:contains">
            <munit-tools:then-return>
                <munit-tools:payload value="#[true]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-variable variableName="sapTid" value="TEST-TID-001" />
        <set-payload value="#[read(readUrl('classpath://test-idoc-matmas.xml'), 'application/xml')]" />
        <flow-ref name="sap-idoc-inbound-receiver-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload]"
            is="#[MunitTools::equalTo('OK')]" />
        <munit-tools:verify-call processor="flow-ref"
            times="0">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute
                    attributeName="name"
                    whereValue="sap-idoc-process-subflow" />
            </munit-tools:with-attributes>
        </munit-tools:verify-call>
    </munit:validation>
</munit:test>
```

### Related

- [SAP IDoc Processing](../sap-idoc-processing/) — Basic IDoc send/receive patterns
- [SAP JCo CloudHub Deployment](../sap-jco-cloudhub-deployment/) — Deploying the native SAP JCo libraries required by this connector
