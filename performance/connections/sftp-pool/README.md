## SFTP Connection Pooling
> Enable or disable SFTP pooling based on usage frequency.

### When to Use
- Frequent SFTP operations benefiting from persistent connections
- Infrequent transfers where pooling wastes resources

### Configuration / Code

```xml
<!-- Enable pooling for frequent operations -->
<sftp:config name="SFTP_Frequent">
    <sftp:connection host="${sftp.host}" port="22" username="${sftp.user}" password="${sftp.password}">
        <pooling-profile maxActive="5" maxIdle="2" maxWait="5000"/>
    </sftp:connection>
</sftp:config>

<!-- Disable pooling for occasional transfers -->
<sftp:config name="SFTP_Occasional">
    <sftp:connection host="${sftp.host}" port="22" username="${sftp.user}" password="${sftp.password}"/>
</sftp:config>
```

### How It Works
1. With pooling: SFTP connections are reused, avoiding SSH handshake overhead
2. Without pooling: each operation opens and closes a new connection

### Gotchas
- SFTP servers may close idle connections — set `maxIdle` timeout shorter than server timeout
- SSH key authentication is more reliable than password for pooled connections
- Pool connections inherit the initial working directory — use absolute paths

### Related
- [HTTP Connection Pool](../http-connection-pool/) — HTTP pooling
- [Connection Timeouts](../connection-timeouts/) — timeout settings
