## Reconnection Strategy
> Configure connector-level reconnection so transient connection failures auto-recover.

### When to Use
- Database connections drop due to network blips or maintenance windows
- HTTP connections to persistent backends need auto-recovery
- You want the connector itself to handle reconnection, not your flow logic

### Configuration / Code

```xml
<!-- Reconnect with limited attempts -->
<db:config name="Database_Config">
    <db:my-sql-connection host="db.example.com" port="3306"
                          database="orders" user="${db.user}" password="${db.password}">
        <reconnection>
            <reconnect frequency="5000" count="3" blocking="true"/>
        </reconnection>
    </db:my-sql-connection>
</db:config>

<!-- Reconnect forever (for always-on services) -->
<http:request-config name="Core_Service">
    <http:request-connection host="core-service.internal" port="443" protocol="HTTPS">
        <reconnection>
            <reconnect-forever frequency="10000" blocking="false"/>
        </reconnection>
    </http:request-connection>
</http:request-config>

<!-- JMS with reconnection -->
<jms:config name="JMS_Config">
    <jms:active-mq-connection>
        <reconnection>
            <reconnect frequency="3000" count="5" blocking="true"/>
        </reconnection>
    </jms:active-mq-connection>
</jms:config>
```

### How It Works
1. `reconnect`: tries to reconnect `count` times with `frequency` ms between attempts
2. `reconnect-forever`: retries indefinitely with the given frequency
3. `blocking="true"`: the calling thread waits during reconnection (use for startup)
4. `blocking="false"`: returns immediately and reconnects in the background (use for runtime)

### Gotchas
- `reconnect-forever` can mask permanent failures — monitor with alerts
- `blocking="true"` at startup prevents the app from accepting traffic until connected
- Reconnection applies to the connection, not individual operations — a query failure is not a reconnection event
- CloudHub workers have a 5-minute startup timeout — if `reconnect-forever` blocks too long, the deploy fails

### Related
- [Until Successful Basic](../until-successful-basic/) — flow-level retry
- [DB Pool Exhaustion](../../connector-errors/db-pool-exhaustion/) — pool-level recovery
- [HTTP Timeout Fallback](../../connector-errors/http-timeout-fallback/) — operation-level fallback
