## Salesforce Invalid Session Recovery
> Catch SFDC:INVALID_SESSION errors and force token refresh transparently.

### When to Use
- Salesforce session tokens expire during long-running batch operations
- OAuth refresh tokens need to be used to get a new access token
- You want transparent re-authentication without manual intervention

### Configuration / Code

```xml
<salesforce:config name="Salesforce_Config">
    <salesforce:oauth-user-pass-connection consumerKey="${sf.consumerKey}"
                                            consumerSecret="${sf.consumerSecret}"
                                            username="${sf.username}"
                                            password="${sf.password}"
                                            tokenUrl="https://login.salesforce.com/services/oauth2/token">
        <reconnection>
            <reconnect frequency="5000" count="2"/>
        </reconnection>
    </salesforce:oauth-user-pass-connection>
</salesforce:config>

<flow name="sfdc-query-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/accounts"/>
    <until-successful maxRetries="1" millisBetweenRetries="2000">
        <salesforce:query config-ref="Salesforce_Config">
            <salesforce:salesforce-query>SELECT Id, Name FROM Account LIMIT 100</salesforce:salesforce-query>
        </salesforce:query>
    </until-successful>
    <error-handler>
        <on-error-propagate type="MULE:RETRY_EXHAUSTED">
            <set-variable variableName="httpStatus" value="502"/>
            <set-payload value='{"error":"Salesforce authentication failed after retry"}' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. The Salesforce connector with `reconnection` config automatically refreshes the token on connection errors
2. `until-successful` retries the query once if the first attempt fails with an invalid session
3. The reconnection strategy acquires a new access token using the stored credentials
4. If retry also fails, the error propagates as `MULE:RETRY_EXHAUSTED`

### Gotchas
- Salesforce rate-limits OAuth token requests — do not retry too aggressively
- Session timeout is 2 hours by default; adjust Salesforce session settings if needed
- Connected App must have "Refresh Token" scope for OAuth refresh to work
- On CloudHub, multiple workers share the same Connected App — token refresh by one worker invalidates the session for others

### Related
- [Salesforce Query Timeout](../salesforce-query-timeout/) — SOQL timeout handling
- [Reconnection Strategy](../../retry/reconnection-strategy/) — connector-level reconnection
