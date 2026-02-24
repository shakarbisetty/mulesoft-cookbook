## Zero-Downtime Database Migration
> Expand-contract pattern for schema changes that support rolling deployments

### When to Use
- Your Mule app uses a database and you need to change the schema
- You deploy with rolling updates or blue-green, so old and new code run simultaneously
- You cannot afford downtime for database migrations

### Configuration

**Phase 1: EXPAND — add new column (backward-compatible)**
```sql
-- V1.1__add_email_column.sql (Flyway migration)
-- Both old and new app versions work with this schema

ALTER TABLE customers ADD COLUMN email VARCHAR(255);

-- Backfill from existing data (if applicable)
UPDATE customers
SET email = CONCAT(LOWER(REPLACE(name, ' ', '.')), '@legacy.example.com')
WHERE email IS NULL;

-- Do NOT drop the old column yet
-- Do NOT add NOT NULL constraint yet
```

**Phase 2: MIGRATE — deploy new app version that uses new column**
```xml
<!-- New version writes to both old and new columns -->
<flow name="update-customer-flow">
    <db:update config-ref="Database_Config" doc:name="Update Customer">
        <db:sql>
            UPDATE customers
            SET name = :name,
                email = :email,
                contact_info = :email  /* also write to old column for old version */
            WHERE id = :id
        </db:sql>
        <db:input-parameters>
            #[{
                "id": payload.id,
                "name": payload.name,
                "email": payload.email
            }]
        </db:input-parameters>
    </db:update>
</flow>

<!-- New version reads from new column -->
<flow name="get-customer-flow">
    <db:select config-ref="Database_Config" doc:name="Get Customer">
        <db:sql>
            SELECT id, name,
                COALESCE(email, contact_info) as email  /* fallback to old column */
            FROM customers
            WHERE id = :id
        </db:sql>
        <db:input-parameters>
            #[{ "id": attributes.uriParams.id }]
        </db:input-parameters>
    </db:select>
</flow>
```

**Phase 3: CONTRACT — remove old column (after all replicas are on new version)**
```sql
-- V1.2__remove_contact_info_column.sql
-- Only run after ALL app instances are on the new version

-- Add NOT NULL constraint now that all rows have data
ALTER TABLE customers ALTER COLUMN email SET NOT NULL;

-- Drop the old column
ALTER TABLE customers DROP COLUMN contact_info;

-- Add index for performance
CREATE INDEX idx_customers_email ON customers (email);
```

**Flyway configuration (pom.xml)**
```xml
<plugin>
    <groupId>org.flywaydb</groupId>
    <artifactId>flyway-maven-plugin</artifactId>
    <version>10.6.0</version>
    <configuration>
        <url>${db.url}</url>
        <user>${db.user}</user>
        <password>${db.password}</password>
        <locations>
            <location>filesystem:src/main/resources/db/migration</location>
        </locations>
        <outOfOrder>false</outOfOrder>
        <validateOnMigrate>true</validateOnMigrate>
    </configuration>
</plugin>
```

**CI pipeline with migration phases**
```yaml
stages:
  - expand-db     # Phase 1: add new columns
  - deploy-app    # Phase 2: deploy new app version
  - verify        # Verify all replicas on new version
  - contract-db   # Phase 3: remove old columns (manual gate)

expand-db:
  stage: expand-db
  script:
    - mvn flyway:migrate -Dflyway.target=1.1
    - echo "Schema expanded. Old and new app versions compatible."

deploy-app:
  stage: deploy-app
  script:
    - mvn mule:deploy -B -Denv=prod

verify:
  stage: verify
  script:
    - bash scripts/verify-all-replicas.sh
    - echo "All replicas running new version."

contract-db:
  stage: contract-db
  when: manual  # Only run after confirming all old instances are gone
  script:
    - mvn flyway:migrate -Dflyway.target=1.2
    - echo "Schema contracted. Old columns removed."
```

### How It Works
1. **Expand**: Add new columns/tables without removing anything; schema is compatible with both versions
2. **Migrate**: Deploy the new app version that reads/writes to new columns; dual-write to old columns for compatibility
3. **Contract**: After all old replicas are gone, remove the old columns and add constraints
4. Each phase is a separate CI stage; the contract phase requires manual approval
5. Flyway tracks which migrations have been applied to prevent re-running

### Gotchas
- The EXPAND and CONTRACT phases must be separate deployments — never combine them
- Dual-write logic in the MIGRATE phase adds complexity; remove it in the next release
- `ALTER TABLE` on large tables can lock the table; use `pt-online-schema-change` for MySQL or `pg_repack` for PostgreSQL
- Flyway migrations are forward-only; avoid `flyway:undo` in production
- Test the full expand-contract cycle in QA before running in production

### Related
- [rolling-update](../rolling-update/) — Rolling updates that need backward-compatible schemas
- [blue-green](../blue-green/) — Blue-green deploys with shared database
- [rollback-strategies](../rollback-strategies/) — Rollback when schema changes go wrong
