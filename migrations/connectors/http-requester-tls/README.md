## HTTP Requester TLS 1.2 to 1.3 Migration
> Upgrade HTTP Requester TLS configuration from 1.2 to 1.3

### When to Use
- External APIs requiring TLS 1.3
- Security audit mandates TLS 1.3
- Upgrading to Java 11/17 with native TLS 1.3

### Configuration / Code

#### 1. TLS Context with TLS 1.3

```xml
<tls:context name="TLS_1_3_Context">
    <tls:trust-store path="truststore.p12"
        password="${secure::truststore.password}" type="pkcs12" />
    <tls:key-store path="keystore.p12"
        keyPassword="${secure::key.password}"
        password="${secure::keystore.password}" type="pkcs12" />
    <tls:protocols>
        <tls:protocol value="TLSv1.3" />
        <tls:protocol value="TLSv1.2" />
    </tls:protocols>
    <tls:cipher-suites>
        <tls:cipher-suite value="TLS_AES_256_GCM_SHA384" />
        <tls:cipher-suite value="TLS_AES_128_GCM_SHA256" />
    </tls:cipher-suites>
</tls:context>
```

#### 2. HTTP Requester with TLS

```xml
<http:request-config name="HTTPS_Config">
    <http:request-connection host="api.example.com" port="443"
        protocol="HTTPS" tlsContext="TLS_1_3_Context" />
</http:request-config>
```

#### 3. Convert JKS to PKCS12

```bash
keytool -importkeystore \
    -srckeystore keystore.jks -srcstoretype JKS \
    -destkeystore keystore.p12 -deststoretype PKCS12
```

### How It Works
1. TLS 1.3 is supported natively in Java 11+
2. TLS 1.3 uses different cipher suites (TLS_AES_* prefix)
3. Protocol list determines which TLS versions the client negotiates

### Migration Checklist
- [ ] Verify Java 11+ runtime
- [ ] Convert JKS keystores to PKCS12
- [ ] Update TLS context with TLS 1.3 protocols
- [ ] Update cipher suites
- [ ] Test connectivity to all endpoints
- [ ] Remove TLS 1.0/1.1

### Gotchas
- TLS 1.3 cipher suites differ from TLS 1.2
- Java 8 does NOT support TLS 1.3
- Some older servers may not support TLS 1.3
- JKS triggers deprecation warnings on Java 11+

### Related
- [java8-to-11](../../java-versions/java8-to-11/) - Java upgrade
- [credentials-to-secure-props](../../security/credentials-to-secure-props/) - Secure credentials
