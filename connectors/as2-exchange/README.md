## AS2 Message Exchange

> AS2 (Applicability Statement 2) message exchange for B2B — send and receive with certificate management, MDN configuration, and partner onboarding.

### When to Use

- Exchanging EDI documents (X12, EDIFACT) with trading partners who require AS2 transport
- Replacing legacy AS2 solutions (Cyclone, OpenAS2, Sterling) with MuleSoft-native B2B
- Meeting compliance requirements that mandate non-repudiation (signed MDNs) for document exchange
- Building a multi-partner B2B gateway that handles both AS2 and API-based partners

### AS2 vs SFTP vs API Comparison

| Feature | AS2 | SFTP | REST API |
|---------|-----|------|----------|
| Non-repudiation | Yes (signed MDN) | No | No (unless custom) |
| Encryption | S/MIME (end-to-end) | TLS (transport only) | TLS (transport only) |
| Push model | Yes (HTTP POST) | No (polling required) | Yes |
| Receipt confirmation | MDN (sync or async) | None built-in | HTTP status codes |
| Firewall friendly | Yes (HTTPS port 443) | Requires port 22 | Yes (HTTPS port 443) |
| Partner onboarding | Certificate exchange required | SSH key exchange | API key or OAuth |
| Standard compliance | EDIINT RFC 4130 | RFC 4253 | Varies |
| Typical use case | EDI B2B with large retailers | Legacy file exchange | Modern API integrations |
| Payload types | Any (typically EDI) | Any file | JSON/XML structured data |

### Configuration

#### AS2 Connector Global Config

```xml
<as2-mule4:config name="AS2_Config" doc:name="AS2 Config">
    <as2-mule4:connection
        selfAS2Id="${as2.selfId}"
        partnerAS2Id="${as2.partnerId}"
        selfCertificateAlias="${as2.selfCertAlias}"
        partnerCertificateAlias="${as2.partnerCertAlias}"
        keystorePath="${as2.keystorePath}"
        keystorePassword="${as2.keystorePassword}"
        keystoreType="JKS" />
</as2-mule4:config>
```

#### Inbound AS2 Receiver

```xml
<flow name="as2-receive-flow">
    <as2-mule4:listener config-ref="AS2_Config"
        doc:name="AS2 Listener"
        path="/as2/receive"
        mdnMode="SYNC"
        signMdn="true"
        encryptionAlgorithm="DES_EDE3_CBC"
        signingAlgorithm="SHA256" />

    <logger level="INFO"
        message="AS2 message received from: #[attributes.as2From] | Message-ID: #[attributes.messageId]" />

    <!-- Store raw payload for audit -->
    <os:store key="#[attributes.messageId]"
        objectStore="AS2_Audit_Store"
        doc:name="Audit Raw Message">
        <os:value><![CDATA[#[output application/json
---
{
    messageId: attributes.messageId,
    from: attributes.as2From,
    to: attributes.as2To,
    receivedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    contentType: attributes.headers.'content-type',
    signed: attributes.signed,
    encrypted: attributes.encrypted,
    payloadSize: sizeOf(payload)
}]]]></os:value>
    </os:store>

    <!-- Route based on content type -->
    <choice doc:name="Route by Content Type">
        <when expression="#[attributes.headers.'content-type' contains 'edi']">
            <flow-ref name="edi-inbound-processing-flow" />
        </when>
        <when expression="#[attributes.headers.'content-type' contains 'xml']">
            <flow-ref name="xml-inbound-processing-flow" />
        </when>
        <otherwise>
            <flow-ref name="generic-inbound-processing-flow" />
        </otherwise>
    </choice>

    <error-handler>
        <on-error-propagate type="AS2:AUTHENTICATION">
            <logger level="ERROR"
                message="AS2 authentication failed: #[error.description]" />
        </on-error-propagate>
        <on-error-propagate type="AS2:DECRYPTION">
            <logger level="ERROR"
                message="AS2 decryption failed — check partner certificate: #[error.description]" />
        </on-error-propagate>
    </error-handler>
</flow>
```

#### Outbound AS2 Send

```xml
<flow name="as2-send-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/as2/send"
        allowedMethods="POST" />

    <set-variable variableName="partnerId" value="#[attributes.queryParams.partnerId]" />

    <!-- Look up partner configuration -->
    <flow-ref name="lookup-partner-config" />

    <ee:transform doc:name="Prepare AS2 Payload">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/edi-x12
---
payload]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <as2-mule4:send config-ref="AS2_Config"
        doc:name="Send AS2 Message"
        url="#[vars.partnerConfig.as2Url]"
        as2From="${as2.selfId}"
        as2To="#[vars.partnerConfig.as2Id]"
        subject="EDI Document"
        contentType="application/edi-x12"
        requestMdn="true"
        mdnMicAlgorithm="SHA256"
        signMessage="true"
        encryptMessage="true"
        encryptionAlgorithm="DES_EDE3_CBC"
        signingAlgorithm="SHA256" />

    <logger level="INFO"
        message="AS2 message sent to #[vars.partnerId] | MDN status: #[payload.mdnDisposition]" />

    <!-- Validate MDN -->
    <choice doc:name="Check MDN Status">
        <when expression="#[payload.mdnDisposition contains 'processed']">
            <ee:transform doc:name="Success Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "delivered",
    messageId: payload.messageId,
    mdnMessageId: payload.mdnMessageId,
    mdnDisposition: payload.mdnDisposition,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </when>
        <otherwise>
            <ee:transform doc:name="Failure Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "failed",
    messageId: payload.messageId,
    mdnDisposition: payload.mdnDisposition,
    error: "MDN indicates delivery failure",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </otherwise>
    </choice>
</flow>
```

#### Partner Configuration Management

```xml
<sub-flow name="lookup-partner-config">
    <db:select config-ref="Database_Config" doc:name="Get Partner Config">
        <db:sql><![CDATA[SELECT
    partner_id, as2_id, as2_url, certificate_alias,
    encryption_algorithm, signing_algorithm,
    mdn_mode, sign_mdn, active
FROM as2_partners
WHERE partner_id = :partnerId AND active = true]]></db:sql>
        <db:input-parameters><![CDATA[#[{ partnerId: vars.partnerId }]]]></db:input-parameters>
    </db:select>

    <validation:is-not-empty value="#[payload]"
        message="Partner not found or inactive: #[vars.partnerId]" />

    <set-variable variableName="partnerConfig"
        value="#[output application/java --- {
            as2Id: payload[0].as2_id,
            as2Url: payload[0].as2_url,
            certAlias: payload[0].certificate_alias,
            encryptionAlg: payload[0].encryption_algorithm,
            signingAlg: payload[0].signing_algorithm,
            mdnMode: payload[0].mdn_mode,
            signMdn: payload[0].sign_mdn
        }]" />
</sub-flow>
```

#### Certificate Setup

```xml
<!-- Keystore containing your private key + partner public certificates -->
<!--
    JKS Keystore setup (run these commands):

    1. Generate your AS2 key pair:
       keytool -genkeypair -alias mycompany-as2 -keyalg RSA -keysize 2048 \
         -validity 730 -keystore as2-keystore.jks -storepass changeit \
         -dname "CN=mycompany.com, OU=B2B, O=MyCompany, L=City, ST=State, C=US"

    2. Export your public certificate (send to partner):
       keytool -exportcert -alias mycompany-as2 -keystore as2-keystore.jks \
         -storepass changeit -file mycompany-as2.cer

    3. Import partner's public certificate:
       keytool -importcert -alias partner-as2 -keystore as2-keystore.jks \
         -storepass changeit -file partner-as2.cer -noprompt

    4. Verify keystore contents:
       keytool -list -keystore as2-keystore.jks -storepass changeit
-->

<!-- Certificate rotation flow -->
<flow name="as2-cert-health-check-flow">
    <scheduler doc:name="Daily Cert Check">
        <scheduling-strategy>
            <cron expression="0 0 8 * * ?" timeZone="UTC" />
        </scheduling-strategy>
    </scheduler>

    <java:invoke-static
        class="com.mycompany.as2.CertificateChecker"
        method="checkExpiry(String, String, int)"
        doc:name="Check Certificate Expiry">
        <java:args><![CDATA[#[{
            keystorePath: p('as2.keystorePath'),
            keystorePassword: p('as2.keystorePassword'),
            warningDays: 30
        }]]]></java:args>
    </java:invoke-static>

    <choice doc:name="Expiry Warning?">
        <when expression="#[payload.expiringCerts != null and sizeOf(payload.expiringCerts) > 0]">
            <foreach collection="#[payload.expiringCerts]">
                <logger level="WARN"
                    message="Certificate expiring soon: alias=#[payload.alias], expires=#[payload.expiryDate], days=#[payload.daysRemaining]" />
            </foreach>
            <flow-ref name="send-cert-expiry-alert" />
        </when>
    </choice>
</flow>
```

#### Async MDN Configuration

```xml
<!-- For partners requiring async MDN -->
<flow name="as2-send-async-mdn-flow">
    <as2-mule4:send config-ref="AS2_Config"
        doc:name="Send AS2 with Async MDN"
        url="#[vars.partnerConfig.as2Url]"
        as2From="${as2.selfId}"
        as2To="#[vars.partnerConfig.as2Id]"
        requestMdn="true"
        asyncMdnUrl="https://${as2.publicHost}/as2/async-mdn"
        mdnMicAlgorithm="SHA256"
        signMessage="true"
        encryptMessage="true" />

    <!-- Store pending MDN for correlation -->
    <os:store key="#[payload.messageId]"
        objectStore="AS2_Pending_MDN_Store"
        doc:name="Store Pending MDN">
        <os:value><![CDATA[#[output application/json
---
{
    messageId: payload.messageId,
    partnerId: vars.partnerId,
    sentAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"},
    status: "awaiting_mdn"
}]]]></os:value>
    </os:store>
</flow>

<!-- Receive async MDN callback -->
<flow name="as2-async-mdn-receiver-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/as2/async-mdn"
        allowedMethods="POST" />

    <as2-mule4:mdn-listener doc:name="Parse Async MDN" />

    <logger level="INFO"
        message="Async MDN received for message: #[attributes.originalMessageId] | Status: #[payload.disposition]" />

    <!-- Correlate with original message -->
    <os:retrieve key="#[attributes.originalMessageId]"
        objectStore="AS2_Pending_MDN_Store"
        doc:name="Get Original Message" />

    <os:remove key="#[attributes.originalMessageId]"
        objectStore="AS2_Pending_MDN_Store"
        doc:name="Clear Pending MDN" />
</flow>
```

### How It Works

1. **Certificate exchange** — Before any message flow, both parties exchange public certificates. Your private key signs outgoing messages; the partner's public key encrypts them. The partner uses their private key to decrypt and your public key to verify signatures
2. **Outbound send** — The AS2 connector serializes the payload, signs it with your private key (S/MIME), encrypts it with the partner's public certificate, and sends via HTTP POST to the partner's AS2 endpoint
3. **MDN receipt** — The partner returns a Message Disposition Notification (MDN) confirming receipt. Synchronous MDN comes in the HTTP response; asynchronous MDN arrives later via a callback URL
4. **Inbound receive** — The AS2 listener accepts incoming HTTP POST messages, decrypts with your private key, verifies the partner's signature, and returns an MDN
5. **Audit trail** — Every message (sent and received) is logged with message ID, partner, timestamp, and MDN status for compliance and troubleshooting
6. **Partner routing** — A database-driven partner configuration table maps partner IDs to AS2 settings (URL, certificates, encryption preferences), enabling multi-partner support

### Gotchas

- **MDN async vs sync** — Synchronous MDN returns in the same HTTP response (simpler). Asynchronous MDN comes as a separate HTTP POST to your callback URL (required by some large retailers). Async MDN requires a publicly accessible endpoint and correlation logic to match the MDN with the original message
- **Certificate expiry** — AS2 certificates have expiration dates (typically 1-2 years). If a certificate expires, all messages to/from that partner fail immediately. Implement a daily certificate health check that alerts 30+ days before expiry
- **Firewall rules for inbound AS2** — Inbound AS2 requires your MuleSoft endpoint to be publicly accessible on HTTPS. Work with your network team to configure firewall rules, load balancer SSL termination, and URL path routing. CloudHub deployments can use the VPC's load balancer
- **S/MIME content type** — AS2 wraps payloads in S/MIME envelopes. The `Content-Type` header changes from your payload's type (e.g., `application/edi-x12`) to `application/pkcs7-mime`. The AS2 module handles this transparently, but custom middleware or logging must account for it
- **Large message handling** — AS2 over HTTP is not designed for very large files (>100MB). For large payloads, consider chunked transfer encoding or switch to SFTP for the transport while using AS2 only for smaller transactional documents
- **Testing with partners** — Partner AS2 testing is time-consuming. Use Mendelson AS2 (open-source) or Drummond Certified testing to validate your AS2 implementation before partner go-live. Always test with the exact certificate and configuration that will be used in production
- **Duplicate message detection** — The `Message-ID` header uniquely identifies each AS2 message. Implement idempotent processing based on Message-ID to handle retransmissions when MDNs are lost

### Related

- [EDI Processing](../edi-processing/) — AS2 is the transport; EDI is the payload format. Typically used together
- [SFTP Guaranteed Delivery](../sftp-guaranteed-delivery/) — Alternative file-based transport when AS2 is not required
- [SAP IDoc Processing](../sap-idoc-processing/) — For partners using SAP, IDocs may travel over AS2 as the transport
