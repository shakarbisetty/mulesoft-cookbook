## HTTP Proxy Auth Configuration

> HTTP proxy setup with NTLM, Kerberos, and Basic authentication for corporate environments in Mule 4.

### When to Use

- MuleSoft application runs behind a corporate proxy that requires authentication
- Outbound HTTP/HTTPS requests fail with connection refused or 407 Proxy Authentication Required
- Need to configure different proxies for different external endpoints (e.g., internal APIs vs external SaaS)
- CloudHub VPC uses a proxy gateway for all outbound traffic

### The Problem

Corporate networks route all outbound HTTP traffic through a proxy server that requires authentication (typically NTLM for Windows environments, Kerberos for Active Directory, or Basic auth). Mule 4's HTTP request connector supports proxy configuration, but the documentation does not cover NTLM domain syntax, Kerberos keytab setup, or proxy bypass lists. Developers waste hours debugging connection failures that are simply proxy misconfiguration.

### Configuration

#### Basic Proxy Authentication

```xml
<http:request-config name="HTTP_With_Basic_Proxy"
    doc:name="HTTP with Basic Proxy">
    <http:request-connection
        host="${external.api.host}"
        port="443"
        protocol="HTTPS">
        <http:proxy-config>
            <http:proxy
                host="${proxy.host}"
                port="${proxy.port}"
                username="${proxy.username}"
                password="${proxy.password}" />
        </http:proxy-config>
    </http:request-connection>
</http:request-config>

<flow name="http-proxy-basic-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/external"
        allowedMethods="GET" />

    <http:request config-ref="HTTP_With_Basic_Proxy"
        method="GET"
        path="/api/v1/data" />

    <error-handler>
        <on-error-continue type="HTTP:CONNECTIVITY">
            <ee:transform doc:name="Proxy Error Response">
                <ee:message>
                    <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: "PROXY_CONNECTION_FAILED",
    message: error.description,
    hint: if (error.description contains "407")
              "Proxy authentication failed. Verify proxy credentials."
          else if (error.description contains "Connection refused")
              "Cannot reach proxy server. Verify proxy host and port."
          else
              "Check network connectivity and proxy configuration."
}]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-continue>
    </error-handler>
</flow>
```

#### NTLM Proxy Authentication (Windows Domain)

```xml
<http:request-config name="HTTP_With_NTLM_Proxy"
    doc:name="HTTP with NTLM Proxy">
    <http:request-connection
        host="${external.api.host}"
        port="443"
        protocol="HTTPS">
        <http:proxy-config>
            <http:ntlm-proxy
                host="${proxy.host}"
                port="${proxy.port}"
                username="${proxy.ntlm.username}"
                password="${proxy.ntlm.password}"
                ntlmDomain="${proxy.ntlm.domain}" />
        </http:proxy-config>
    </http:request-connection>
</http:request-config>
```

Properties file for NTLM:

```yaml
# NTLM proxy configuration
proxy.host: proxy.corp.example.com
proxy.port: 8080
proxy.ntlm.username: svc-mulesoft
proxy.ntlm.password: ${secure::proxy.password}
proxy.ntlm.domain: CORPDOMAIN
```

#### Conditional Proxy — Internal vs External

```xml
<!-- No proxy for internal APIs -->
<http:request-config name="Internal_API_Config"
    doc:name="Internal API (No Proxy)">
    <http:request-connection
        host="${internal.api.host}"
        port="443"
        protocol="HTTPS" />
</http:request-config>

<!-- Proxy for external APIs -->
<http:request-config name="External_API_Config"
    doc:name="External API (With Proxy)">
    <http:request-connection
        host="${external.api.host}"
        port="443"
        protocol="HTTPS">
        <http:proxy-config>
            <http:proxy
                host="${proxy.host}"
                port="${proxy.port}"
                username="${proxy.username}"
                password="${proxy.password}"
                nonProxyHosts="${proxy.bypass.hosts}" />
        </http:proxy-config>
    </http:request-connection>
</http:request-config>
```

Properties for proxy bypass:

```yaml
# Bypass proxy for these hosts (pipe-delimited)
proxy.bypass.hosts: "localhost|*.internal.corp.com|10.*|192.168.*"
```

#### Dynamic Proxy Selection

```xml
<flow name="http-dynamic-proxy-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/route"
        allowedMethods="POST" />

    <!-- Determine if proxy is needed based on target URL -->
    <ee:transform doc:name="Check Proxy Need">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/java
var targetHost = payload.targetUrl replace /https?:\/\// with "" replace /\/.*/ with ""
var internalDomains = ["internal.corp.com", "10.", "192.168.", "localhost"]
var isInternal = internalDomains some ((domain) -> targetHost contains domain)
---
{
    targetUrl: payload.targetUrl,
    targetHost: targetHost,
    useProxy: !isInternal,
    proxyConfig: if (!isInternal) null
                 else {
                     host: p('proxy.host'),
                     port: p('proxy.port') as Number
                 }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <set-variable variableName="routeConfig" value="#[payload]" />

    <choice doc:name="Route Through Proxy?">
        <when expression="#[vars.routeConfig.useProxy]">
            <http:request config-ref="External_API_Config"
                method="#[payload.method default 'GET']"
                url="#[vars.routeConfig.targetUrl]" />
        </when>
        <otherwise>
            <http:request config-ref="Internal_API_Config"
                method="#[payload.method default 'GET']"
                url="#[vars.routeConfig.targetUrl]" />
        </otherwise>
    </choice>
</flow>
```

#### System-Level Proxy (JVM Properties)

```xml
<!-- Set in mule-artifact.json or as JVM args for system-wide proxy -->
<!-- mule-artifact.json -->
```

```json
{
    "minMuleVersion": "4.4.0",
    "javaSpecificationVersions": ["1.8", "11", "17"],
    "secureProperties": ["proxy.password"],
    "properties": {
        "http.proxyHost": "proxy.corp.example.com",
        "http.proxyPort": "8080",
        "https.proxyHost": "proxy.corp.example.com",
        "https.proxyPort": "8443",
        "http.nonProxyHosts": "localhost|*.internal.corp.com"
    }
}
```

#### Proxy Health Check

```xml
<flow name="proxy-health-check-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/health/proxy"
        allowedMethods="GET" />

    <try doc:name="Test Proxy Connectivity">
        <http:request config-ref="External_API_Config"
            method="GET"
            url="https://httpbin.org/ip"
            responseTimeout="10000" />

        <ee:transform doc:name="Proxy Up">
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "UP",
    proxyHost: p('proxy.host'),
    proxyPort: p('proxy.port'),
    externalIp: payload.origin default "unknown",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <error-handler>
            <on-error-continue type="ANY">
                <ee:transform doc:name="Proxy Down">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    status: "DOWN",
    proxyHost: p('proxy.host'),
    proxyPort: p('proxy.port'),
    error: error.description,
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
                    </ee:message>
                    <ee:set-attributes><![CDATA[%dw 2.0
output application/java
---
{ httpStatus: 503 }]]></ee:set-attributes>
                </ee:transform>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### Gotchas

- **NTLM domain format** — The `ntlmDomain` property takes just the domain name (e.g., `CORPDOMAIN`), not `CORPDOMAIN\username`. The username and domain are separate fields. Using `DOMAIN\user` in the username field causes authentication failure
- **HTTPS proxy and CONNECT** — HTTPS through a proxy uses the HTTP CONNECT method to tunnel the TLS connection. Some corporate proxies inspect CONNECT traffic (SSL interception). If the proxy uses its own CA for interception, you must add that CA to your Mule truststore
- **`nonProxyHosts` uses pipe separator** — Unlike environment variables that use commas, the Mule `nonProxyHosts` property uses pipe `|` as separator and supports wildcards with `*`. Incorrect separator causes all traffic to go through the proxy
- **Proxy on CloudHub** — CloudHub Shared Space does not need a proxy for outbound HTTPS; it goes through Anypoint's network. CloudHub with VPC may require a proxy if your VPC routes through a corporate gateway. CloudHub 2.0 on RTF always uses your corporate network and likely needs proxy config
- **Connection pooling through proxy** — HTTP connections through a proxy cannot be reused as efficiently as direct connections. The proxy may close idle connections sooner than your Mule pooling expects. Set `idleTimeout` on the HTTP requester to 30 seconds when going through a proxy
- **NTLM is not thread-safe by default** — NTLM authentication requires a stateful connection. If multiple threads share the same HTTP requester config through an NTLM proxy, authentication can fail intermittently. Limit concurrency or use dedicated requester configs per flow

### Testing

```xml
<munit:test name="proxy-407-handling-test"
    description="Verify 407 proxy auth error is handled">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:then-throw exception="#[new java::org.mule.runtime.api.connection.ConnectionException('407 Proxy Authentication Required')]" />
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="http-proxy-basic-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:assert-that
            expression="#[payload.error]"
            is="#[MunitTools::equalTo('PROXY_CONNECTION_FAILED')]" />
    </munit:validation>
</munit:test>
```

### Related

- [HTTP mTLS Complete Setup](../http-mtls-complete-setup/) — TLS configuration that may be affected by proxy SSL interception
