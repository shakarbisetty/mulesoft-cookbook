## Email OAuth2 for Office 365 and Gmail

> OAuth2 configuration for IMAP and SMTP with Microsoft 365 and Google Gmail, replacing deprecated Basic auth (username/password) in Mule 4.

### When to Use

- Microsoft disabled Basic auth for Exchange Online (October 2022) and your email connector stopped working
- Google requires OAuth2 for Gmail API access and your app-specific password approach is blocked by org policy
- Building email-triggered integrations that read inbound emails or send transactional emails via corporate mailboxes
- Migrating from legacy SMTP relay to modern OAuth2-authenticated email

### The Problem

Both Microsoft and Google have deprecated or disabled Basic authentication for email protocols (IMAP, POP3, SMTP). Mule 4's Email connector supports OAuth2, but the configuration requires client registration in Azure AD or Google Cloud Console, correct scope definitions, and token refresh handling that is not covered in the standard connector documentation. Developers get `AUTH FAILED` errors and cannot determine whether the issue is the OAuth app registration, the token, or the connector config.

### Configuration

#### Microsoft 365 — Azure AD App Registration

Before configuring Mule, register an application in Azure AD:

1. Azure Portal > App registrations > New registration
2. Set redirect URI to `https://localhost` (for initial token acquisition)
3. API Permissions: add `Mail.ReadWrite`, `Mail.Send`, `IMAP.AccessAsUser.All`, `SMTP.Send`
4. Certificates & secrets: Create a client secret
5. Note the Application (client) ID and Tenant ID

#### Microsoft 365 — IMAP with OAuth2

```xml
<!-- OAuth2 token provider for Microsoft 365 -->
<oauth2:token-manager-config name="MS365_Token_Manager"
    doc:name="MS365 Token Manager" />

<http:request-config name="MS365_OAuth_Config"
    doc:name="MS365 OAuth Config">
    <http:request-connection
        host="login.microsoftonline.com"
        port="443"
        protocol="HTTPS" />
</http:request-config>

<email:imap-config name="O365_IMAP_Config" doc:name="O365 IMAP Config">
    <email:imaps-connection
        host="outlook.office365.com"
        port="993"
        user="${o365.email}"
        password="${o365.accessToken}">
        <email:oauth2-connection
            accessToken="#[vars.accessToken]" />
        <tls:context>
            <tls:trust-store insecure="false" />
        </tls:context>
    </email:imaps-connection>
</email:imap-config>
```

#### Token Acquisition Flow for Microsoft 365

```xml
<flow name="o365-token-acquisition-flow">
    <scheduler doc:name="Refresh Token Every 50 Minutes">
        <scheduling-strategy>
            <fixed-frequency frequency="50" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <http:request config-ref="MS365_OAuth_Config"
        method="POST"
        path="/${o365.tenantId}/oauth2/v2.0/token">
        <http:body><![CDATA[#[output application/x-www-form-urlencoded --- {
            client_id: p('o365.clientId'),
            client_secret: p('o365.clientSecret'),
            scope: "https://outlook.office365.com/.default",
            grant_type: "client_credentials"
        }]]]></http:body>
        <http:headers><![CDATA[#[output application/java --- {
            "Content-Type": "application/x-www-form-urlencoded"
        }]]]></http:headers>
    </http:request>

    <ee:transform doc:name="Extract Token">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    accessToken: payload.access_token,
    expiresIn: payload.expires_in,
    tokenType: payload.token_type,
    acquiredAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Store token for use by email flows -->
    <os:store key="o365_access_token"
        objectStore="Token_Store">
        <os:value><![CDATA[#[payload.accessToken]]]></os:value>
    </os:store>

    <logger level="INFO"
        message="O365 OAuth token refreshed. Expires in #[payload.expiresIn] seconds." />
</flow>
```

#### Microsoft 365 — Send Email via SMTP with OAuth2

```xml
<flow name="o365-send-email-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/email/send"
        allowedMethods="POST" />

    <!-- Get current access token -->
    <os:retrieve key="o365_access_token"
        objectStore="Token_Store"
        doc:name="Get Access Token" />

    <set-variable variableName="accessToken" value="#[payload]" />

    <!-- Use Microsoft Graph API instead of SMTP for OAuth2 -->
    <ee:transform doc:name="Build Graph API Email">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
var emailPayload = vars.originalPayload
---
{
    message: {
        subject: emailPayload.subject,
        body: {
            contentType: emailPayload.contentType default "HTML",
            content: emailPayload.body
        },
        toRecipients: (emailPayload.to default []) map {
            emailAddress: { address: $ }
        },
        ccRecipients: (emailPayload.cc default []) map {
            emailAddress: { address: $ }
        }
    },
    saveToSentItems: true
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <http:request method="POST"
        url="https://graph.microsoft.com/v1.0/users/${o365.email}/sendMail">
        <http:headers><![CDATA[#[output application/java --- {
            "Authorization": "Bearer " ++ vars.accessToken,
            "Content-Type": "application/json"
        }]]]></http:headers>
        <http:response-validator>
            <http:success-status-code-validator values="200..299" />
        </http:response-validator>
    </http:request>

    <set-payload value="#[output application/json --- {
        status: 'sent',
        timestamp: now() as String {format: 'yyyy-MM-dd\\'T\\'HH:mm:ss\\'Z\\''}
    }]" />

    <error-handler>
        <on-error-continue type="HTTP:UNAUTHORIZED">
            <logger level="ERROR"
                message="OAuth token expired or invalid. Triggering token refresh." />
            <flow-ref name="o365-token-acquisition-flow" />
            <set-payload value="#[output application/json --- {
                error: 'TOKEN_EXPIRED',
                message: 'Token refreshed. Please retry.'
            }]" />
        </on-error-continue>
    </error-handler>
</flow>
```

#### Gmail — OAuth2 Configuration

```xml
<flow name="gmail-token-acquisition-flow">
    <scheduler doc:name="Refresh Token Every 50 Minutes">
        <scheduling-strategy>
            <fixed-frequency frequency="50" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <http:request method="POST"
        url="https://oauth2.googleapis.com/token">
        <http:body><![CDATA[#[output application/x-www-form-urlencoded --- {
            client_id: p('gmail.clientId'),
            client_secret: p('gmail.clientSecret'),
            refresh_token: p('gmail.refreshToken'),
            grant_type: "refresh_token"
        }]]]></http:body>
    </http:request>

    <os:store key="gmail_access_token"
        objectStore="Token_Store">
        <os:value><![CDATA[#[payload.access_token]]]></os:value>
    </os:store>
</flow>
```

#### Gmail — Read Emails via Gmail API

```xml
<flow name="gmail-read-inbox-flow">
    <scheduler doc:name="Poll Every 5 Minutes">
        <scheduling-strategy>
            <fixed-frequency frequency="5" timeUnit="MINUTES" />
        </scheduling-strategy>
    </scheduler>

    <os:retrieve key="gmail_access_token"
        objectStore="Token_Store" />
    <set-variable variableName="accessToken" value="#[payload]" />

    <os:retrieve key="gmail_last_check"
        objectStore="Token_Store">
        <os:default-value>0</os:default-value>
    </os:retrieve>
    <set-variable variableName="afterEpoch" value="#[payload]" />

    <!-- List unread messages -->
    <http:request method="GET"
        url="https://gmail.googleapis.com/gmail/v1/users/me/messages">
        <http:headers><![CDATA[#[output application/java --- {
            "Authorization": "Bearer " ++ vars.accessToken
        }]]]></http:headers>
        <http:query-params><![CDATA[#[output application/java --- {
            q: "is:unread after:" ++ vars.afterEpoch,
            maxResults: "50"
        }]]]></http:query-params>
    </http:request>

    <choice doc:name="Has Messages?">
        <when expression="#[payload.messages != null and sizeOf(payload.messages default []) > 0]">
            <foreach collection="#[payload.messages]">
                <!-- Get full message -->
                <http:request method="GET"
                    url="#['https://gmail.googleapis.com/gmail/v1/users/me/messages/' ++ payload.id]">
                    <http:headers><![CDATA[#[output application/java --- {
                        "Authorization": "Bearer " ++ vars.accessToken
                    }]]]></http:headers>
                    <http:query-params><![CDATA[#[output application/java --- {
                        format: "full"
                    }]]]></http:query-params>
                </http:request>

                <ee:transform doc:name="Extract Email Data">
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
var headers = payload.payload.headers
fun getHeader(name: String): String =
    (headers filter ($.name == name))[0].value default ""
---
{
    messageId: payload.id,
    threadId: payload.threadId,
    from: getHeader("From"),
    to: getHeader("To"),
    subject: getHeader("Subject"),
    date: getHeader("Date"),
    snippet: payload.snippet,
    hasAttachments: (payload.payload.parts default []) some ($.filename != "")
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <!-- Process email -->
                <flow-ref name="process-email-subflow" />
            </foreach>
        </when>
    </choice>

    <!-- Update watermark -->
    <os:store key="gmail_last_check"
        objectStore="Token_Store">
        <os:value><![CDATA[#[now() as Number {unit: "seconds"} as String]]]></os:value>
    </os:store>
</flow>
```

### Gotchas

- **Microsoft Basic auth is permanently disabled** — As of October 2022, Microsoft disabled Basic auth for Exchange Online. There is no workaround. You must use OAuth2 (client credentials for daemon apps, authorization code for user-delegated)
- **Client credentials vs delegated permissions** — For automated integrations (no user present), use `client_credentials` grant type with Application permissions in Azure AD. For user-specific mailbox access, use `authorization_code` grant with Delegated permissions. The wrong grant type causes `AADSTS700016` errors
- **Gmail requires refresh token** — Google's OAuth2 access tokens expire in 1 hour. Unlike Microsoft's client credentials flow, Gmail requires a refresh token obtained through an interactive consent flow. Store the refresh token securely in a vault
- **Graph API vs SMTP** — Microsoft recommends Graph API over SMTP for sending emails with OAuth2. SMTP with OAuth2 (XOAUTH2 SASL) is supported but requires enabling "Authenticated SMTP" in the Exchange admin center for each mailbox
- **Token storage security** — Access tokens are bearer tokens. Store them in Object Store with encryption or use Anypoint Secrets Manager. Never log access tokens, even at DEBUG level
- **Rate limits** — Microsoft Graph API allows 10,000 requests per 10 minutes per app per mailbox. Gmail API allows 250 quota units per user per second. Exceeding these limits returns HTTP 429
- **Shared mailbox** — For shared/service mailboxes in O365, use the `users/{mailbox-email}/sendMail` endpoint with application permissions. The OAuth app must have `Mail.Send` permission granted by an admin

### Testing

```xml
<munit:test name="o365-token-refresh-test"
    description="Verify OAuth token acquisition and storage">

    <munit:behavior>
        <munit-tools:mock-when processor="http:request">
            <munit-tools:then-return>
                <munit-tools:payload value="#[{access_token: 'test-token-123', expires_in: 3600, token_type: 'Bearer'}]" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <flow-ref name="o365-token-acquisition-flow" />
    </munit:execution>

    <munit:validation>
        <munit-tools:verify-call processor="os:store"
            times="1" />
    </munit:validation>
</munit:test>
```

### Related

- [HTTP mTLS Complete Setup](../http-mtls-complete-setup/) — Certificate-based auth as alternative to OAuth2 for API calls
