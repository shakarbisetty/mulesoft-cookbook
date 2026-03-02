## HTTP Mutual TLS Complete Setup

> Certificate generation, keystore/truststore configuration, TLS context, and certificate rotation strategy for Mule 4 HTTPS endpoints.

### When to Use

- External partners require mutual TLS (client certificate authentication) to call your MuleSoft API
- Your MuleSoft application must present a client certificate when calling a partner's API
- Regulatory compliance (PCI-DSS, SOX, HIPAA) mandates mTLS for data in transit
- Replacing API key authentication with certificate-based authentication for higher security

### The Problem

Setting up mTLS in MuleSoft involves multiple steps across multiple tools: generating certificates, creating keystores and truststores, configuring TLS contexts, and planning for certificate rotation before expiry. The documentation covers each piece separately, but developers need the end-to-end workflow with the exact `keytool` commands, correct Mule XML configuration, and a rotation strategy that avoids downtime.

### Configuration

#### Step 1: Certificate Generation (keytool commands)

```bash
# Generate server keystore with self-signed cert (for dev/testing)
keytool -genkeypair \
    -alias server-cert \
    -keyalg RSA \
    -keysize 2048 \
    -validity 365 \
    -keystore server-keystore.jks \
    -storepass changeit \
    -keypass changeit \
    -dname "CN=api.example.com, OU=Integration, O=Example Corp, L=Austin, ST=TX, C=US"

# Export server public certificate
keytool -exportcert \
    -alias server-cert \
    -keystore server-keystore.jks \
    -storepass changeit \
    -file server-cert.cer

# Generate client keystore
keytool -genkeypair \
    -alias client-cert \
    -keyalg RSA \
    -keysize 2048 \
    -validity 365 \
    -keystore client-keystore.jks \
    -storepass changeit \
    -keypass changeit \
    -dname "CN=client.partner.com, OU=Integration, O=Partner Corp, L=London, C=GB"

# Export client public certificate
keytool -exportcert \
    -alias client-cert \
    -keystore client-keystore.jks \
    -storepass changeit \
    -file client-cert.cer

# Import client cert into server truststore (server trusts client)
keytool -importcert \
    -alias client-cert \
    -file client-cert.cer \
    -keystore server-truststore.jks \
    -storepass changeit \
    -noprompt

# Import server cert into client truststore (client trusts server)
keytool -importcert \
    -alias server-cert \
    -file server-cert.cer \
    -keystore client-truststore.jks \
    -storepass changeit \
    -noprompt

# For production: import CA-signed cert chain
keytool -importcert \
    -alias root-ca \
    -file root-ca.cer \
    -keystore server-truststore.jks \
    -storepass changeit \
    -noprompt

keytool -importcert \
    -alias intermediate-ca \
    -file intermediate-ca.cer \
    -keystore server-truststore.jks \
    -storepass changeit \
    -noprompt
```

#### Step 2: TLS Context Configuration

```xml
<!-- Server-side mTLS: require client certificate -->
<tls:context name="Server_mTLS_Context" doc:name="Server mTLS Context">
    <tls:key-store
        type="jks"
        path="server-keystore.jks"
        keyPassword="${tls.server.keyPassword}"
        password="${tls.server.storePassword}"
        alias="server-cert" />
    <tls:trust-store
        type="jks"
        path="server-truststore.jks"
        password="${tls.server.truststorePassword}"
        insecure="false" />
</tls:context>

<!-- Client-side mTLS: present client certificate -->
<tls:context name="Client_mTLS_Context" doc:name="Client mTLS Context">
    <tls:key-store
        type="jks"
        path="client-keystore.jks"
        keyPassword="${tls.client.keyPassword}"
        password="${tls.client.storePassword}"
        alias="client-cert" />
    <tls:trust-store
        type="jks"
        path="client-truststore.jks"
        password="${tls.client.truststorePassword}"
        insecure="false" />
</tls:context>
```

#### Step 3: HTTP Listener with mTLS

```xml
<http:listener-config name="HTTPS_mTLS_Listener"
    doc:name="HTTPS mTLS Listener">
    <http:listener-connection
        host="0.0.0.0"
        port="${https.port}"
        tlsContext="Server_mTLS_Context"
        protocol="HTTPS" />
</http:listener-config>

<flow name="mtls-secured-api-flow">
    <http:listener config-ref="HTTPS_mTLS_Listener"
        path="/api/secure/*"
        allowedMethods="GET,POST,PUT" />

    <!-- Extract client certificate info -->
    <ee:transform doc:name="Extract Client Cert Details">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var clientCert = attributes.clientCertificate
---
{
    authenticated: clientCert != null,
    subject: clientCert.subjectDN default "unknown",
    issuer: clientCert.issuerDN default "unknown",
    serialNumber: clientCert.serialNumber default "unknown",
    validFrom: clientCert.notBefore default "unknown",
    validUntil: clientCert.notAfter default "unknown",
    cn: do {
        var dn = clientCert.subjectDN default ""
        var cnMatch = dn match /CN=([^,]+)/
        ---
        cnMatch[1] default "unknown"
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <logger level="INFO"
        message="mTLS request from: #[payload.subject]" />

    <!-- Your business logic here -->
    <set-payload value="#[output application/json --- {
        status: 'authenticated',
        clientCN: payload.cn,
        message: 'mTLS handshake successful'
    }]" />
</flow>
```

#### Step 4: HTTP Request with Client Certificate

```xml
<http:request-config name="Partner_mTLS_Config"
    doc:name="Partner mTLS Config">
    <http:request-connection
        host="${partner.host}"
        port="443"
        protocol="HTTPS"
        tlsContext="Client_mTLS_Context">
        <http:client-socket-properties
            connectionTimeout="30000"
            sendTcpNoDelay="true" />
    </http:request-connection>
</http:request-config>

<flow name="mtls-outbound-call-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/partner/data"
        allowedMethods="GET" />

    <http:request config-ref="Partner_mTLS_Config"
        method="GET"
        path="/api/v1/data" />

    <ee:transform doc:name="Process Partner Response">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    source: "partner-api",
    data: payload,
    retrievedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <error-handler>
        <on-error-continue type="HTTP:CONNECTIVITY">
            <ee:transform doc:name="TLS Error Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "TLS_HANDSHAKE_FAILED",
    message: error.description,
    hint: if (error.description contains "PKIX")
              "Certificate not trusted. Verify truststore contains partner's CA certificate."
          else if (error.description contains "certificate_unknown")
              "Partner does not trust our client certificate. Share the public cert with partner."
          else
              "Check keystore/truststore paths and passwords."
}]]></ee:set-payload>
                </ee:message>
                <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 502 }]]></ee:set-attributes>
            </ee:transform>
        </on-error-continue>
    </error-handler>
</flow>
```

#### Certificate Expiry Monitoring

```xml
<flow name="mtls-cert-expiry-check-flow">
    <scheduler doc:name="Daily Cert Check">
        <scheduling-strategy>
            <cron expression="0 0 8 * * ?" timeZone="UTC" />
        </scheduling-strategy>
    </scheduler>

    <ee:transform doc:name="Check Certificate Expiry">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
// In production, read from Java keystore programmatically
// This is a monitoring payload structure
var certs = [
    { alias: "server-cert", expiresAt: "2026-06-15T00:00:00Z" },
    { alias: "client-cert", expiresAt: "2026-03-01T00:00:00Z" },
    { alias: "partner-ca", expiresAt: "2027-01-15T00:00:00Z" }
]
---
{
    checkDate: now() as String {format: "yyyy-MM-dd"},
    certificates: certs map {
        alias: $.alias,
        expiresAt: $.expiresAt,
        daysUntilExpiry: ($.expiresAt as DateTime - now()) as Number {unit: "days"},
        status: if (($.expiresAt as DateTime - now()) as Number {unit: "days"} < 30) "CRITICAL"
                else if (($.expiresAt as DateTime - now()) as Number {unit: "days"} < 90) "WARNING"
                else "OK"
    },
    alertsNeeded: sizeOf(certs filter (
        ($.expiresAt as DateTime - now()) as Number {unit: "days"} < 30
    ))
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <choice doc:name="Send Alerts?">
        <when expression="#[payload.alertsNeeded > 0]">
            <logger level="ERROR"
                message="CERTIFICATE EXPIRY ALERT: #[payload.alertsNeeded] certificates expiring within 30 days" />
            <!-- Send alert via email, Slack, PagerDuty, etc. -->
        </when>
    </choice>
</flow>
```

### Gotchas

- **JKS vs PKCS12** — JKS is Java-specific and deprecated in newer Java versions. PKCS12 (`.p12`) is the industry standard. Use `type="pkcs12"` in the TLS context if using `.p12` files. Convert JKS to PKCS12: `keytool -importkeystore -srckeystore server.jks -destkeystore server.p12 -deststoretype PKCS12`
- **CloudHub keystore path** — On CloudHub, keystores must be in `src/main/resources/` and referenced without a path prefix. The `path` attribute is relative to the classpath, not the filesystem
- **`insecure="false"` is critical** — Setting `insecure="true"` on the truststore disables certificate validation entirely, bypassing mTLS. This should only be used in development and never in production
- **Client certificate chain** — The client keystore must contain the full certificate chain (client cert + intermediate CA + root CA), not just the client cert. Without the chain, the server cannot validate the client certificate
- **Certificate rotation requires redeployment** — Mule loads keystores at startup. To rotate certificates, you must replace the keystore files and restart/redeploy the application. Plan rotations with at least 30 days overlap between old and new certificates
- **SNI (Server Name Indication)** — If the partner host uses SNI to serve different certificates for different domains on the same IP, ensure the HTTP request connector's `host` matches the expected SNI hostname
- **TLS 1.2 minimum** — Mule 4.4+ defaults to TLS 1.2. If a partner requires TLS 1.3, you need Mule 4.6+ with Java 17. Configure `enabledProtocols` in the TLS context to restrict versions

### Testing

```xml
<munit:test name="mtls-missing-cert-test"
    description="Verify proper error when client cert is missing">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:then-throw exception="#[new java::javax.net.ssl.SSLHandshakeException('certificate_unknown')]" />
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="mtls-outbound-call-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.error]"
            is="#[MunitTools::equalTo('TLS_HANDSHAKE_FAILED')]" />
    </munit:validation>
</munit:test>
```

### Related

- [HTTP Proxy Auth Config](../http-proxy-auth-config/) — Corporate proxy configuration that may intercept TLS
- [SFTP Guaranteed Delivery](../sftp-guaranteed-delivery/) — Key-based authentication as an alternative to certificate auth
