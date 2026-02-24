## Database Connector Major Version Upgrade
> Upgrade the Mule Database Connector across major versions

### When to Use
- Runtime upgrade requires newer DB connector version
- Need connection pool improvements or new database support
- Current version has known CVEs

### Configuration / Code

#### 1. POM Update

```xml
<dependency>
    <groupId>org.mule.connectors</groupId>
    <artifactId>mule-db-connector</artifactId>
    <version>1.15.2</version>
    <classifier>mule-plugin</classifier>
</dependency>
```

#### 2. Connection Pool Configuration

```xml
<db:config name="Database_Config">
    <db:my-sql-connection host="${db.host}" port="3306"
        database="${db.name}" user="${db.user}"
        password="${secure::db.password}">
        <db:pooling-profile
            maxPoolSize="20"
            minPoolSize="5"
            acquireIncrement="2"
            maxWait="30"
            maxWaitUnit="SECONDS" />
        <db:connection-properties>
            <db:connection-property key="useSSL" value="true" />
            <db:connection-property key="requireSSL" value="true" />
            <db:connection-property key="serverTimezone" value="UTC" />
        </db:connection-properties>
    </db:my-sql-connection>
</db:config>
```

#### 3. Parameterized Queries

```xml
<db:select config-ref="Database_Config">
    <db:sql>SELECT * FROM customers WHERE status = :status</db:sql>
    <db:input-parameters>#[{
        'status': vars.customerStatus
    }]</db:input-parameters>
</db:select>
```

#### 4. JDBC Driver Updates

```xml
<!-- MySQL 8+ (renamed artifact) -->
<dependency>
    <groupId>com.mysql</groupId>
    <artifactId>mysql-connector-j</artifactId>
    <version>8.3.0</version>
</dependency>

<!-- PostgreSQL -->
<dependency>
    <groupId>org.postgresql</groupId>
    <artifactId>postgresql</artifactId>
    <version>42.7.3</version>
</dependency>

<!-- Oracle (Java 11+) -->
<dependency>
    <groupId>com.oracle.database.jdbc</groupId>
    <artifactId>ojdbc11</artifactId>
    <version>23.3.0.23.09</version>
</dependency>
```

### How It Works
1. DB Connector wraps JDBC drivers with Mule-native operations
2. Connection pool manages database connection lifecycle
3. Parameterized queries prevent SQL injection
4. JDBC drivers must be compatible with both connector and database version

### Migration Checklist
- [ ] Update connector version in POM
- [ ] Update JDBC driver to compatible version
- [ ] Review connection pool settings
- [ ] Add SSL/TLS properties
- [ ] Test all database operations
- [ ] Verify stored procedure calls

### Gotchas
- MySQL renamed artifact from `mysql-connector-java` to `mysql-connector-j` in 8.x
- Oracle `ojdbc11` is for Java 11+; `ojdbc17` for Java 17+
- Some SQL syntax varies between JDBC driver versions

### Related
- [connector-bulk-upgrade](../../runtime-upgrades/connector-bulk-upgrade/) - Bulk upgrade
- [mule44-to-46](../../runtime-upgrades/mule44-to-46/) - Runtime context