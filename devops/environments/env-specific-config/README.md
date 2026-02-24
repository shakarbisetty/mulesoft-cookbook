## Environment-Specific Configuration
> Global property files with env prefix strategy and cascading overrides

### When to Use
- You manage multiple environments (DEV, QA, STAGING, PROD) with overlapping config
- You want a single property file per environment with clear naming conventions
- You need a cascading override strategy: defaults → env-specific → Runtime Manager

### Configuration

**Project structure**
```
src/main/resources/
├── config/
│   ├── config-common.yaml        # Shared defaults
│   ├── config-dev.yaml           # DEV overrides
│   ├── config-qa.yaml            # QA overrides
│   ├── config-staging.yaml       # STAGING overrides
│   └── config-prod.yaml          # PROD overrides
└── mule-artifact.json
```

**config/config-common.yaml**
```yaml
http:
  port: "8081"
  basePath: "/api/v1"
  responseTimeout: "30000"

logging:
  level: "INFO"
  includePayload: "false"

retry:
  maxAttempts: "3"
  delayMs: "1000"
  multiplier: "2"
```

**config/config-dev.yaml**
```yaml
logging:
  level: "DEBUG"
  includePayload: "true"

retry:
  maxAttempts: "1"
  delayMs: "100"
```

**config/config-prod.yaml**
```yaml
http:
  responseTimeout: "10000"

logging:
  level: "WARN"
  includePayload: "false"

retry:
  maxAttempts: "5"
  delayMs: "2000"
```

**src/main/mule/global.xml — cascading load order**
```xml
<!-- 1. Common defaults (loaded first) -->
<configuration-properties
    file="config/config-common.yaml"
    doc:name="Common Config" />

<!-- 2. Environment overrides (loaded second, wins on conflicts) -->
<configuration-properties
    file="config/config-${env}.yaml"
    doc:name="Environment Config" />

<!-- 3. Runtime Manager properties win over everything (implicit) -->

<global-property name="env" value="dev" />
```

### How It Works
1. **Common config** provides defaults shared across all environments
2. **Environment config** overrides only the values that differ per environment
3. **Runtime Manager properties** override both file-based layers (highest priority)
4. The `env` global property defaults to `dev` for local development
5. At deploy time, pass `-Denv=prod` to load `config-prod.yaml`

### Gotchas
- `configuration-properties` elements are resolved in document order; the LAST one wins on conflicts
- This means environment-specific files must be loaded AFTER the common file
- Missing properties in an env file simply fall through to the common defaults (not an error)
- Do not put secrets in any committed config file; use secure properties or external secrets
- Property names must be identical across all files for overrides to work

### Related
- [property-externalization](../property-externalization/) — Detailed YAML externalization
- [secure-properties](../secure-properties/) — Encrypted properties
- [feature-flags](../feature-flags/) — Toggle behavior per environment
