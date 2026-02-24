## Injection Prevention
> Protect APIs against SQL injection, XSS, and SSRF attacks using parameterized queries, input validation, and URL allowlists.

### When to Use
- APIs accept user input that is used in database queries
- API responses render user-supplied content that could contain scripts
- Flows make outbound HTTP requests using URLs or hostnames derived from input
- Security audit flags injection risks in your Mule applications

### Configuration / Code

#### SQL Injection — Safe vs Unsafe

**UNSAFE — String concatenation (never do this):**

```xml
<!-- VULNERABLE: User input interpolated into SQL string -->
<db:select config-ref="Database_Config">
    <db:sql>
        #["SELECT * FROM products WHERE name = '" ++ attributes.queryParams.name ++ "'"]
    </db:sql>
</db:select>
<!-- Attacker input: ' OR '1'='1' --
     Resulting SQL: SELECT * FROM products WHERE name = '' OR '1'='1' -- -->
```

**SAFE — Parameterized queries (always do this):**

```xml
<!-- SAFE: Parameterized query — input is never part of the SQL string -->
<db:select config-ref="Database_Config">
    <db:sql>SELECT * FROM products WHERE name = :productName AND category = :category</db:sql>
    <db:input-parameters><![CDATA[#[{
        productName: attributes.queryParams.name,
        category: attributes.queryParams.category
    }]]]></db:input-parameters>
</db:select>
```

**SAFE — Dynamic column ordering with allowlist:**

```xml
<!-- When you need dynamic ORDER BY, validate against an allowlist -->
<ee:transform>
    <ee:message>
        <ee:set-payload><![CDATA[%dw 2.0
output application/java

var allowedSortColumns = ["name", "price", "created_at", "category"]
var requestedSort = attributes.queryParams.sort default "name"
var sortColumn = if (allowedSortColumns contains requestedSort)
                    requestedSort
                 else "name"
---
"SELECT * FROM products ORDER BY " ++ sortColumn ++ " ASC"]]></ee:set-payload>
    </ee:message>
</ee:transform>

<db:select config-ref="Database_Config">
    <db:sql>#[payload]</db:sql>
</db:select>
```

#### XSS Prevention — Input Sanitization

```xml
<flow name="create-comment">
    <http:listener config-ref="api-httpListenerConfig" path="/comments" method="POST"/>

    <!-- Validate and sanitize input -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

// Strip HTML tags to prevent stored XSS
fun stripHtml(text: String): String =
    text replace /(<([^>]+)>)/  with ""

// Encode special characters for safe storage
fun encodeHtml(text: String): String =
    text
        replace "&" with "&amp;"
        replace "<" with "&lt;"
        replace ">" with "&gt;"
        replace '"' with "&quot;"
        replace "'" with "&#x27;"

// Validate input length and content
var rawBody = payload.body default ""
var rawTitle = payload.title default ""
---
{
    title: if (sizeOf(rawTitle) > 200)
              error("Title exceeds maximum length")
           else encodeHtml(stripHtml(rawTitle)),
    body: if (sizeOf(rawBody) > 5000)
              error("Body exceeds maximum length")
          else encodeHtml(stripHtml(rawBody)),
    authorId: payload.authorId
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <db:insert config-ref="Database_Config">
        <db:sql>INSERT INTO comments (title, body, author_id) VALUES (:title, :body, :authorId)</db:sql>
        <db:input-parameters><![CDATA[#[{
            title: payload.title,
            body: payload.body,
            authorId: payload.authorId
        }]]]></db:input-parameters>
    </db:insert>
</flow>
```

#### Input Validation with DataWeave Regex

```xml
<flow name="validate-input">
    <http:listener config-ref="api-httpListenerConfig" path="/users" method="POST"/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

// Validation patterns
var emailPattern = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/
var phonePattern = /^\+?[1-9]\d{1,14}$/
var alphanumPattern = /^[a-zA-Z0-9\s\-_.]{1,100}$/
var uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

fun validate(value: String, pattern: Regex, fieldName: String): String =
    if (value matches pattern) value
    else error("Invalid " ++ fieldName ++ " format")
---
{
    name: validate(payload.name default "", alphanumPattern, "name"),
    email: validate(payload.email default "", emailPattern, "email"),
    phone: validate(payload.phone default "", phonePattern, "phone"),
    referralCode: if (payload.referralCode?)
                      validate(payload.referralCode, uuidPattern, "referralCode")
                  else null
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### SSRF Prevention — URL Allowlist for HTTP Requester

```xml
<!-- SSRF-safe: validate outbound URL against allowlist before making request -->
<flow name="fetch-external-resource">
    <http:listener config-ref="api-httpListenerConfig" path="/proxy" method="GET"/>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

var requestedUrl = attributes.queryParams.url default ""

// Allowlisted hosts
var allowedHosts = [
    "api.partner1.com",
    "api.partner2.com",
    "data.public-service.gov"
]

// Block private/internal IP ranges
var privateIpPatterns = [
    /^10\./,
    /^172\.(1[6-9]|2[0-9]|3[01])\./,
    /^192\.168\./,
    /^127\./,
    /^0\./,
    /^169\.254\./,
    /^localhost$/i,
    /^::1$/,
    /^fc00:/i,
    /^fe80:/i
]

// Extract hostname from URL
var urlHost = (requestedUrl match /^https?:\/\/([^:\/\s]+)/)[1] default ""

var isAllowedHost = allowedHosts contains urlHost
var isPrivateIp = privateIpPatterns some ((pattern) -> urlHost matches pattern)
---
{
    url: requestedUrl,
    host: urlHost,
    allowed: isAllowedHost and not isPrivateIp,
    reason: if (isPrivateIp) "Private/internal addresses are blocked"
            else if (not isAllowedHost) "Host not in allowlist"
            else "OK"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <choice>
        <when expression="#[not payload.allowed]">
            <set-payload value='#[output application/json ---
                { error: "Forbidden", message: payload.reason }]'
                         mimeType="application/json"/>
            <raise-error type="SECURITY:FORBIDDEN"/>
        </when>
        <otherwise>
            <http:request method="GET" url="#[payload.url]"
                          config-ref="External_Request_Config"
                          followRedirects="false">
                <http:response-validator>
                    <http:success-status-code-validator values="200..299"/>
                </http:response-validator>
            </http:request>
        </otherwise>
    </choice>
</flow>

<!-- HTTP Requester config — enforce HTTPS only -->
<http:request-config name="External_Request_Config">
    <http:request-connection protocol="HTTPS">
        <tls:context>
            <tls:trust-store type="jks" path="truststore.jks" password="${secure::truststore.password}"/>
        </tls:context>
    </http:request-connection>
</http:request-config>
```

### How It Works
1. **Parameterized queries** — the DB connector separates SQL structure from data; the database driver escapes input values, making injection impossible
2. **Input validation** — DataWeave regex patterns enforce format rules at the API entry point, rejecting malformed input before it reaches any downstream system
3. **HTML encoding** — special characters are encoded to their HTML entity equivalents, preventing browsers from executing injected scripts
4. **URL allowlisting** — outbound requests are checked against a list of permitted hostnames and blocked from private IP ranges, preventing SSRF
5. **Redirect blocking** — `followRedirects="false"` on the HTTP Requester prevents attackers from using open redirects to bypass the URL allowlist

### Gotchas
- **Stored XSS via database** — sanitizing on input is necessary but not sufficient; if legacy data exists unsanitized, you must also encode on output
- **SSRF via redirect following** — even with URL allowlists, if `followRedirects` is `true` (the default), an allowed host could redirect to an internal IP; always set `followRedirects="false"` for user-controlled URLs
- **DNS rebinding** — an attacker's domain can resolve to an internal IP after the allowlist check; for high-security scenarios, resolve the DNS first and check the IP before making the request
- **Dynamic SQL column/table names** — parameterized queries only protect values, not identifiers; use strict allowlists for any dynamic column or table names
- **Content-Type confusion** — an API returning `text/html` instead of `application/json` can trigger XSS in browsers; always set explicit `Content-Type: application/json` response headers
- **Batch operations** — when processing arrays of input, validate each element individually; one malicious item in a batch should not bypass validation
- **RAML/OAS validation** — APIkit validation catches type and format violations at the API layer, but does not protect against injection in valid string fields; always add application-level validation

### Related
- [OWASP API Top 10 Mapping](../owasp-api-top10-mapping/)
- [Excessive Data Exposure](../excessive-data-exposure/)
- [Zero Trust with Flex Gateway](../zero-trust-flex-gateway/)
- [Security Scanning in CI/CD](../security-scanning-cicd/)
- [Custom Business Validation](../../../error-handling/validation/custom-business-validation/)
