## Property Externalization
> External YAML per environment with Spring placeholders and Runtime Manager overrides

### When to Use
- You need different database URLs, API keys, or feature flags per environment
- You want config files in the repo but overridable at deploy time
- You follow the twelve-factor app methodology for config management

### Configuration

**src/main/resources/config/config-dev.yaml**
```yaml
http:
  port: "8081"
  basePath: "/api/v1"

db:
  host: "dev-db.internal"
  port: "5432"
  name: "orders_dev"
  maxPoolSize: "5"

api:
  timeout: "30000"
  retryCount: "3"

feature:
  asyncProcessing: "false"
```

**src/main/resources/config/config-prod.yaml**
```yaml
http:
  port: "8081"
  basePath: "/api/v1"

db:
  host: "${db.host}"
  port: "${db.port}"
  name: "orders_prod"
  maxPoolSize: "20"

api:
  timeout: "10000"
  retryCount: "5"

feature:
  asyncProcessing: "true"
```

**src/main/mule/global.xml — environment-aware config loader**
```xml
<configuration-properties
    file="config/config-${env}.yaml"
    doc:name="Environment Config" />

<global-property name="env" value="dev" doc:name="Default Environment" />
```

**Using properties in flows**
```xml
<http:listener-config name="HTTP_Listener_Config">
    <http:listener-connection
        host="0.0.0.0"
        port="${http.port}" />
</http:listener-config>

<db:config name="Database_Config">
    <db:generic-connection
        url="jdbc:postgresql://${db.host}:${db.port}/${db.name}"
        driverClassName="org.postgresql.Driver"
        user="${db.user}"
        password="${db.password}" />
    <db:pooling-profile maxPoolSize="${db.maxPoolSize}" />
</db:config>
```

**Deploy with environment override**
```bash
# The `env` property selects which config file loads
mvn mule:deploy -B \
    -Denv=prod \
    -Ddb.host=prod-db.internal \
    -Ddb.port=5432 \
    -Ddb.user=app_user \
    -Ddb.password=encrypted_value
```

### How It Works
1. `configuration-properties` loads `config/config-${env}.yaml` where `env` is set at deploy time
2. Default `env=dev` ensures local development works without extra flags
3. Property placeholders (`${db.host}`) resolve at startup from the loaded file
4. Runtime Manager properties override file-based values, enabling secrets to be injected externally
5. Each environment gets its own YAML file; shared defaults go in a base file loaded first

### Gotchas
- Property names are case-sensitive and must match exactly between YAML and placeholder references
- Nested YAML keys are flattened with dots: `db.host` maps to `db: host:` in YAML
- If a placeholder cannot be resolved at startup, the app fails to deploy — always provide defaults
- Do not put secrets in YAML files committed to Git; use secure properties or Runtime Manager
- The `configuration-properties` element order matters; later files override earlier ones

### Related
- [secure-properties](../secure-properties/) — Encrypt sensitive values
- [env-specific-config](../env-specific-config/) — Global property file strategy
- [no-rebuild-promotion](../no-rebuild-promotion/) — Deploy same JAR everywhere
