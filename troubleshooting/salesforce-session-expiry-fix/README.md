## Salesforce Session Expiry Fix
> Handle INVALID_SESSION_ID errors with auto-reconnect patterns for the MuleSoft Salesforce Connector

### When to Use
- Getting `INVALID_SESSION_ID` errors in production after hours of successful operation
- Salesforce connector works initially but fails after the session timeout period
- Batch jobs that run longer than the Salesforce session timeout fail mid-process
- Need a resilient Salesforce connection that survives token expiration

### The Problem

Salesforce sessions expire after a configurable timeout (default 2 hours, minimum 15 minutes). The MuleSoft Salesforce Connector caches the session token and reuses it. When the token expires, the next request fails with `INVALID_SESSION_ID`. The connector does NOT automatically re-authenticate by default. In production, this causes intermittent failures that are difficult to reproduce because they depend on timing.

### The Error

```
org.mule.extension.salesforce.api.exception.SalesforceException:
  INVALID_SESSION_ID: Session expired or invalid
  Error type: SALESFORCE:INVALID_SESSION
```

Or in SOAP responses:
```xml
<soapenv:Fault>
    <faultcode>sf:INVALID_SESSION_ID</faultcode>
    <faultstring>INVALID_SESSION_ID: Session expired or invalid</faultstring>
</soapenv:Fault>
```

### Root Cause Analysis

```
Timeline:
  T+0:    Mule starts, authenticates with Salesforce (OAuth or username/password)
  T+0:    Session token cached by Salesforce Connector
  T+0 to T+2h: All requests succeed using cached token
  T+2h:   Salesforce invalidates the session (default timeout)
  T+2h+1: Next request fails with INVALID_SESSION_ID
  T+2h+1: If no reconnect logic -> ERROR propagates to caller
```

**Why the session expires:**
1. Session timeout in Salesforce Setup (default: 2 hours)
2. Admin manually revoked the session
3. Password change invalidated all sessions
4. Session limit exceeded (Salesforce limits concurrent sessions per user)
5. Salesforce maintenance/upgrade invalidated sessions

### Solution 1: Reconnection Strategy (Recommended)

The Salesforce Connector supports reconnection strategies:

```xml
<salesforce:config name="Salesforce_Config">
    <salesforce:oauth-user-password-connection
        consumerKey="${sf.consumerKey}"
        consumerSecret="${sf.consumerSecret}"
        username="${sf.username}"
        password="${sf.password}"
        securityToken="${sf.securityToken}"
        tokenUrl="https://login.salesforce.com/services/oauth2/token">

        <!-- Reconnection strategy: retry on connection failures -->
        <reconnection>
            <reconnect frequency="5000" count="3"/>
        </reconnection>
    </salesforce:oauth-user-password-connection>
</salesforce:config>
```

**This handles the initial connection. For session expiry during operation, add error handling:**

### Solution 2: Error Handler with Retry

```xml
<flow name="salesforceQueryFlow">
    <http:listener config-ref="HTTP" path="/sf/accounts"/>

    <try>
        <salesforce:query config-ref="Salesforce_Config">
            <salesforce:salesforce-query>
                SELECT Id, Name, Industry FROM Account WHERE CreatedDate = TODAY
            </salesforce:salesforce-query>
        </salesforce:query>

        <error-handler>
            <on-error-continue type="SALESFORCE:INVALID_SESSION">
                <logger level="WARN"
                    message="Salesforce session expired, forcing reconnection"/>

                <!-- Force connector to re-authenticate -->
                <salesforce:invalidate-connection config-ref="Salesforce_Config"/>

                <!-- Retry the query -->
                <salesforce:query config-ref="Salesforce_Config">
                    <salesforce:salesforce-query>
                        SELECT Id, Name, Industry FROM Account WHERE CreatedDate = TODAY
                    </salesforce:salesforce-query>
                </salesforce:query>
            </on-error-continue>
        </error-handler>
    </try>
</flow>
```

### Solution 3: Until Successful with Connection Invalidation

```xml
<flow name="resilientSalesforceFlow">
    <http:listener config-ref="HTTP" path="/sf/data"/>

    <until-successful maxRetries="3" millisBetweenRetries="2000">
        <try>
            <salesforce:query config-ref="Salesforce_Config">
                <salesforce:salesforce-query>
                    SELECT Id, Name FROM Account LIMIT 100
                </salesforce:salesforce-query>
            </salesforce:query>
            <error-handler>
                <on-error-propagate type="SALESFORCE:INVALID_SESSION">
                    <!-- Invalidate so next retry gets a fresh token -->
                    <salesforce:invalidate-connection config-ref="Salesforce_Config"/>
                    <!-- Re-raise to trigger until-successful retry -->
                    <raise-error type="APP:SESSION_EXPIRED"
                        description="SF session expired, retrying"/>
                </on-error-propagate>
            </error-handler>
        </try>
    </until-successful>
</flow>
```

### Solution 4: OAuth 2.0 with Refresh Token (Best for Production)

OAuth with refresh tokens allows the connector to get a new access token without user interaction:

```xml
<salesforce:config name="Salesforce_OAuth">
    <salesforce:oauth-jwt-connection
        consumerKey="${sf.consumerKey}"
        keyStorePath="certs/salesforce-keystore.jks"
        storePassword="${sf.keystore.password}"
        principal="${sf.username}"
        tokenUrl="https://login.salesforce.com/services/oauth2/token"
        audienceUrl="https://login.salesforce.com">

        <reconnection>
            <reconnect frequency="3000" count="5"/>
        </reconnection>
    </salesforce:oauth-jwt-connection>
</salesforce:config>
```

**JWT Bearer flow advantages:**
- No password to expire or rotate
- No security token dependency
- Token refresh is automatic
- Certificate-based authentication is more secure

### Salesforce Session Settings to Check

Log into Salesforce Setup and verify these settings:

```
Setup > Security > Session Settings:
  - Session Timeout: 2 hours (default)
  - Lock sessions to the IP address from which they originated: DISABLE for integration users
  - Lock sessions to the domain in which they were first used: DISABLE for integration users

Setup > Users > [integration user]:
  - Profile should be "Integration User" or custom profile
  - API Enabled: YES
  - Session Timeout override: Set to maximum (24 hours) for integration users

Setup > Connected Apps > [your connected app]:
  - Refresh token policy: "Refresh token is valid until revoked"
  - IP Relaxation: "Relax IP restrictions"
```

### Diagnostic Steps

#### Step 1: Confirm the Error

```bash
grep -i "INVALID_SESSION\|session expired\|session invalid" mule_ee.log | head -10
```

#### Step 2: Check Session Timing

```bash
# Find when sessions expire
grep "Salesforce" mule_ee.log | grep -i "auth\|token\|session" | \
  awk '{print $1, $2}' | head -20

# Calculate time between successful auth and failure
# If the gap matches the Salesforce timeout setting, confirmed.
```

#### Step 3: Check Salesforce Login History

In Salesforce: Setup > Users > Login History
- Look for your integration user
- Check "Login Type" and "Status"
- "Invalid Password" or "Failed" entries indicate credential issues

#### Step 4: Check API Limits

```bash
# Query Salesforce API limits
curl -H "Authorization: Bearer <token>" \
  "https://<instance>.salesforce.com/services/data/v59.0/limits/" | \
  jq '.DailyApiRequests, .ConcurrentPerOrgLongTxn'
```

### Batch Job Pattern

For long-running batch jobs that exceed the session timeout:

```xml
<flow name="sfBatchFlow">
    <scheduler>
        <scheduling-strategy>
            <cron expression="0 0 2 * * ?"/>
        </scheduling-strategy>
    </scheduler>

    <!-- Query in smaller batches to avoid session timeout during processing -->
    <set-variable variableName="offset" value="#[0]"/>
    <set-variable variableName="batchSize" value="#[2000]"/>
    <set-variable variableName="hasMore" value="#[true]"/>

    <until-successful maxRetries="3" millisBetweenRetries="5000">
        <foreach collection="#[1 to 100]">
            <choice>
                <when expression="#[vars.hasMore]">
                    <try>
                        <salesforce:query config-ref="Salesforce_Config">
                            <salesforce:salesforce-query>
                                SELECT Id, Name FROM Account
                                ORDER BY Id
                                LIMIT :batchSize OFFSET :offset
                            </salesforce:salesforce-query>
                            <salesforce:parameters>
                                #[{batchSize: vars.batchSize, offset: vars.offset}]
                            </salesforce:parameters>
                        </salesforce:query>

                        <set-variable variableName="hasMore"
                            value="#[sizeOf(payload) == vars.batchSize]"/>
                        <set-variable variableName="offset"
                            value="#[vars.offset + vars.batchSize]"/>

                        <!-- Process batch -->
                        <flow-ref name="processBatch"/>

                        <error-handler>
                            <on-error-continue type="SALESFORCE:INVALID_SESSION">
                                <salesforce:invalidate-connection
                                    config-ref="Salesforce_Config"/>
                                <raise-error type="APP:RETRY"/>
                            </on-error-continue>
                        </error-handler>
                    </try>
                </when>
            </choice>
        </foreach>
    </until-successful>
</flow>
```

### Gotchas
- **`invalidate-connection` is not available in all connector versions** — requires Salesforce Connector 10.x+. Older versions require workarounds like restarting the connection config.
- **OAuth JWT requires a certificate in Salesforce** — you must upload the public certificate to the Connected App in Salesforce Setup. Self-signed certificates work.
- **Session timeout is per-user, not per-app** — if another application uses the same integration user and exceeds the session limit, YOUR sessions get invalidated too. Use separate integration users per application.
- **"Lock sessions to IP" breaks CloudHub** — if this Salesforce setting is enabled, and your CloudHub worker's outbound IP changes (common on shared workers), the session is immediately invalidated.
- **Password expiration is silent** — Salesforce password policies can expire integration user passwords. The error looks like INVALID_SESSION but the root cause is an expired password. Set integration user passwords to "Password Never Expires."
- **Concurrent session limits** — Salesforce limits concurrent sessions per user. Default is ~10. If your Mule app has multiple workers, each maintaining a session, you can hit this limit. Check with: Setup > Company Information > User Licenses.
- **Sandbox refresh resets credentials** — when a Salesforce sandbox is refreshed from production, all OAuth tokens and connected app configurations are reset. Plan for re-authentication after sandbox refresh.
- **Rate limiting vs. session expiry** — Salesforce returns different errors for rate limiting (REQUEST_LIMIT_EXCEEDED) vs. session expiry (INVALID_SESSION_ID). Don't conflate them — they need different fixes.

### Related
- [Top 10 Production Incidents](../top-10-production-incidents/) — common production failures including connectivity
- [Connection Pool Sizing](../connection-pool-sizing/) — connection management principles
- [Timeout Hierarchy](../timeout-hierarchy/) — timeout layers that interact with Salesforce calls
- [Batch Performance Tuning](../batch-performance-tuning/) — batch patterns for large Salesforce data
