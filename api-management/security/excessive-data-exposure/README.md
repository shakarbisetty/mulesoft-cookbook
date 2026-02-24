## Excessive Data Exposure
> Prevent APIs from returning more data than the client is authorized to see using response filtering, field-level access control, and dynamic masking.

### When to Use
- API responses include internal or sensitive fields that not all consumers should see
- Different API consumers (scopes/roles) need different views of the same resource
- Compliance requirements mandate PII masking (GDPR, HIPAA, PCI-DSS)
- Error responses are leaking stack traces, internal paths, or debug information

### Configuration / Code

#### Dynamic Field Masking Based on Client Scope

Use a scope-to-fields mapping to control which fields each OAuth scope can access.

```yaml
# config/field-access-control.yaml
fieldAccessControl:
  resource: /users/{userId}
  defaultFields:
    - id
    - displayName
    - avatar
  scopeMapping:
    user:read:basic:
      - id
      - displayName
      - avatar
    user:read:profile:
      - id
      - displayName
      - avatar
      - email
      - phone
      - address
    user:read:admin:
      - id
      - displayName
      - avatar
      - email
      - phone
      - address
      - ssn
      - dateOfBirth
      - internalNotes
  sensitiveFields:
    - ssn
    - dateOfBirth
    - internalNotes
  maskedFields:
    ssn:
      strategy: partial
      visibleChars: 4
      maskChar: "*"
    phone:
      strategy: partial
      visibleChars: 4
      maskChar: "*"
```

#### DataWeave Response Filter

```xml
<flow name="get-user-profile">
    <http:listener config-ref="api-httpListenerConfig" path="/users/{userId}" method="GET"/>

    <!-- Extract scopes from validated JWT -->
    <set-variable variableName="clientScopes"
                  value="#[authentication.properties.userProperties.scope splitBy ' ']"/>

    <!-- Fetch full user record from backend -->
    <db:select config-ref="Database_Config">
        <db:sql>SELECT * FROM users WHERE user_id = :userId</db:sql>
        <db:input-parameters><![CDATA[#[{ userId: attributes.uriParams.userId }]]]></db:input-parameters>
    </db:select>

    <!-- Filter response based on client scopes -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json

var fieldConfig = readUrl("classpath://config/field-access-control.yaml", "application/yaml")
var scopeMapping = fieldConfig.fieldAccessControl.scopeMapping
var clientScopes = vars.clientScopes

// Determine allowed fields from all granted scopes
var allowedFields = clientScopes
    flatMap ((scope) -> scopeMapping[scope] default [])
    then $ distinctBy $
    then if (isEmpty($)) fieldConfig.fieldAccessControl.defaultFields else $

// Masking rules
var maskRules = fieldConfig.fieldAccessControl.maskedFields

fun maskValue(fieldName: String, value: Any): Any =
    if (maskRules[fieldName]? and maskRules[fieldName].strategy == "partial")
        do {
            var str = value as String
            var visible = maskRules[fieldName].visibleChars as Number
            var maskChar = maskRules[fieldName].maskChar
            ---
            if (sizeOf(str) > visible)
                (maskChar * (sizeOf(str) - visible)) ++ str[-visible to -1]
            else str
        }
    else value

// Filter and mask
var fullRecord = payload[0]
---
allowedFields reduce ((field, acc = {}) ->
    acc ++ if (fullRecord[field]?)
        { (field): maskValue(field, fullRecord[field]) }
    else {}
)]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Response Transformation Policy (Strip Sensitive Fields)

Apply as a custom policy in API Manager to enforce globally without modifying each flow.

```xml
<!-- Custom policy: response-field-filter -->
<policy>
    <before>
        <!-- Extract client scopes into a flow variable for response processing -->
        <set-variable variableName="clientScopes"
                      value="#[authentication.properties.userProperties.scope
                        default '' splitBy ' ']"/>
    </before>

    <after>
        <choice>
            <when expression="#[message.attributes.statusCode >= 200
                              and message.attributes.statusCode < 300
                              and payload.^mimeType contains 'json']">
                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json

// Fields to strip unless client has admin scope
var sensitiveFields = ["ssn", "dateOfBirth", "internalNotes",
                       "passwordHash", "securityQuestions"]
var isAdmin = vars.clientScopes contains "admin"

fun filterObject(obj: Object): Object =
    obj mapObject ((value, key) ->
        if (not isAdmin and (sensitiveFields contains (key as String)))
            {}
        else if (value is Object)
            { (key): filterObject(value) }
        else if (value is Array)
            { (key): value map ((item) ->
                if (item is Object) filterObject(item) else item
            )}
        else
            { (key): value }
    )
---
if (payload is Object) filterObject(payload)
else if (payload is Array) payload map ((item) ->
    if (item is Object) filterObject(item) else item
)
else payload]]></ee:set-payload>
                    </ee:message>
                </ee:transform>
            </when>
        </choice>
    </after>
</policy>
```

#### Sanitize Error Responses

```xml
<!-- Global error handler — strip internal details -->
<error-handler name="global-error-handler">
    <on-error-continue type="ANY" enableNotifications="true" logException="true">
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    error: error.errorType.identifier,
    message: if (p('env') == "production")
                "An error occurred. Contact support with reference: " ++ uuid()
             else
                error.description,
    // NEVER expose these in production:
    // stackTrace, causeMessage, internalPath
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>
        <set-variable variableName="httpStatus"
                      value="#[error.errorType.identifier match {
                        case 'HTTP:NOT_FOUND' -> 404
                        case 'HTTP:BAD_REQUEST' -> 400
                        case 'SECURITY:UNAUTHORIZED' -> 401
                        case 'SECURITY:FORBIDDEN' -> 403
                        else -> 500
                      }]"/>
    </on-error-continue>
</error-handler>
```

### How It Works
1. **Scope extraction** — the JWT or token introspection response provides the client's granted scopes
2. **Field mapping** — a YAML config maps each scope to the fields that scope is allowed to see
3. **Filtering** — DataWeave dynamically selects only the allowed fields from the backend response
4. **Masking** — sensitive fields like SSN are partially masked (e.g., `****1234`) rather than fully removed, when partial visibility is acceptable
5. **Error sanitization** — a global error handler strips stack traces and internal paths from error responses in production
6. **Policy enforcement** — a custom response transformation policy can enforce filtering at the API Manager level, catching any flow that forgot to filter

### Gotchas
- **Nested object exposure** — filtering top-level fields is not enough; if an object has nested structures (e.g., `user.manager.ssn`), the recursive filter must descend into nested objects and arrays
- **Error responses leaking stack traces** — the default Mule error response includes `error.description` and sometimes cause chains; always override with a sanitized response in production
- **Pagination metadata** — total counts can leak information (e.g., revealing how many records exist); consider whether pagination metadata should be filtered for certain scopes
- **GraphQL APIs** — field-level filtering is harder with GraphQL since the client specifies fields; validate the requested fields against the scope's allowlist before execution
- **Caching pitfalls** — if you cache responses, different scopes may get the same cached (unfiltered) response; cache per scope or filter after cache retrieval
- **`fields` query parameter** — even if you support sparse fieldsets (e.g., `?fields=id,name`), never allow clients to request fields outside their scope

### Related
- [OAuth 2.0 Enforcement](../oauth2-enforcement/)
- [Token Introspection](../token-introspection/)
- [OWASP API Top 10 Mapping](../owasp-api-top10-mapping/)
- [Injection Prevention](../injection-prevention/)
