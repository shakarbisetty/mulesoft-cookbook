## Kafka Schema Registry Evolution in MuleSoft

> Configure Confluent Schema Registry with Avro schemas, manage BACKWARD/FORWARD compatibility, and handle consumer adaptation during schema changes.

### When to Use
- Multiple teams produce and consume from the same Kafka topics and need a schema contract
- You need to evolve message schemas without breaking existing consumers
- You want to catch schema violations at produce-time, not consumer-time
- You are migrating from JSON to Avro for compact serialization and schema enforcement

### The Problem
Without a schema registry, Kafka topics are schema-less byte streams. Producers can change message structure at will, and consumers discover the breakage at runtime -- often in production. Schema Registry enforces a contract: producers must register schemas before publishing, and compatibility rules prevent breaking changes. MuleSoft's Kafka connector supports Avro serialization with Schema Registry, but configuring it correctly requires understanding compatibility modes, subject naming strategies, and how DataWeave interacts with Avro-encoded payloads.

### Configuration

#### Kafka Producer with Schema Registry (Avro)

```xml
<kafka:producer-config name="Kafka_Producer_Avro"
    doc:name="Kafka Producer (Avro + Schema Registry)">
    <kafka:producer-connection
        bootstrapServers="${kafka.bootstrap.servers}">
        <kafka:producer-properties>
            <kafka:producer-property key="key.serializer"
                value="org.apache.kafka.common.serialization.StringSerializer" />
            <kafka:producer-property key="value.serializer"
                value="io.confluent.kafka.serializers.KafkaAvroSerializer" />
            <kafka:producer-property key="schema.registry.url"
                value="${schema.registry.url}" />
            <kafka:producer-property key="schema.registry.basic.auth.credentials.source"
                value="USER_INFO" />
            <kafka:producer-property key="schema.registry.basic.auth.user.info"
                value="${schema.registry.api.key}:${schema.registry.api.secret}" />
            <!-- Auto-register new schemas (disable in production) -->
            <kafka:producer-property key="auto.register.schemas" value="false" />
            <!-- Use TopicName strategy: subject = <topic>-value -->
            <kafka:producer-property key="value.subject.name.strategy"
                value="io.confluent.kafka.serializers.subject.TopicNameStrategy" />
        </kafka:producer-properties>
    </kafka:producer-connection>
</kafka:producer-config>
```

#### Kafka Consumer with Avro Deserialization

```xml
<kafka:consumer-config name="Kafka_Consumer_Avro"
    doc:name="Kafka Consumer (Avro + Schema Registry)">
    <kafka:consumer-connection
        bootstrapServers="${kafka.bootstrap.servers}">
        <kafka:consumer-properties>
            <kafka:consumer-property key="key.deserializer"
                value="org.apache.kafka.common.serialization.StringDeserializer" />
            <kafka:consumer-property key="value.deserializer"
                value="io.confluent.kafka.serializers.KafkaAvroDeserializer" />
            <kafka:consumer-property key="schema.registry.url"
                value="${schema.registry.url}" />
            <kafka:consumer-property key="schema.registry.basic.auth.credentials.source"
                value="USER_INFO" />
            <kafka:consumer-property key="schema.registry.basic.auth.user.info"
                value="${schema.registry.api.key}:${schema.registry.api.secret}" />
            <!-- Return GenericRecord, not specific Avro class -->
            <kafka:consumer-property key="specific.avro.reader" value="false" />
        </kafka:consumer-properties>
    </kafka:consumer-connection>
</kafka:consumer-config>
```

#### Avro Schema: Version 1 (Initial)

```json
{
    "type": "record",
    "name": "Order",
    "namespace": "com.example.events",
    "fields": [
        {"name": "orderId", "type": "string"},
        {"name": "customerId", "type": "string"},
        {"name": "amount", "type": "double"},
        {"name": "currency", "type": "string", "default": "USD"},
        {"name": "createdAt", "type": "long", "doc": "Epoch millis"}
    ]
}
```

#### Avro Schema: Version 2 (BACKWARD Compatible)

```json
{
    "type": "record",
    "name": "Order",
    "namespace": "com.example.events",
    "fields": [
        {"name": "orderId", "type": "string"},
        {"name": "customerId", "type": "string"},
        {"name": "amount", "type": "double"},
        {"name": "currency", "type": "string", "default": "USD"},
        {"name": "createdAt", "type": "long", "doc": "Epoch millis"},
        {"name": "region", "type": "string", "default": "US"},
        {"name": "priority", "type": ["null", "string"], "default": null}
    ]
}
```

#### Producer Flow with Schema Evolution

```xml
<flow name="publish-order-v2">
    <http:listener config-ref="HTTP_Listener" path="/api/v2/orders" method="POST" />

    <!-- Transform incoming JSON to match Avro schema v2 -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: payload.orderId,
    customerId: payload.customerId,
    amount: payload.amount as Number,
    currency: payload.currency default "USD",
    createdAt: now() as Number {unit: "milliseconds"},
    // New v2 fields with defaults
    region: payload.region default "US",
    priority: payload.priority default null
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <kafka:publish config-ref="Kafka_Producer_Avro"
        topic="orders"
        key="#[payload.orderId]">
        <kafka:message>
            <kafka:body>#[payload]</kafka:body>
        </kafka:message>
    </kafka:publish>
</flow>
```

#### Consumer Flow Handling Both v1 and v2 Messages

```xml
<flow name="consume-orders-multi-version" maxConcurrency="4">
    <kafka:consumer
        config-ref="Kafka_Consumer_Avro"
        topic="orders"
        groupId="order-enrichment"
        offsetCommit="AUTO" />

    <!--
        The Avro deserializer uses the WRITER schema (embedded in message)
        to decode, then projects onto the READER schema (consumer's version).
        Missing fields get default values automatically.
    -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    orderId: payload.orderId,
    customerId: payload.customerId,
    amount: payload.amount,
    currency: payload.currency,
    createdAt: payload.createdAt,
    // Handle v1 messages that don't have these fields
    region: payload.region default "US",
    priority: payload.priority default "NORMAL"
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <flow-ref name="enrich-and-persist-order" />
</flow>
```

### Compatibility Modes

```
Mode               | Rule                              | Use Case
───────────────────┼───────────────────────────────────┼─────────────────────────
BACKWARD (default) | New schema can read old data      | Add optional fields,
                   | Delete fields, add defaults       | consumers upgrade first
───────────────────┼───────────────────────────────────┼─────────────────────────
FORWARD            | Old schema can read new data      | Remove optional fields,
                   | Add fields, remove defaults       | producers upgrade first
───────────────────┼───────────────────────────────────┼─────────────────────────
FULL               | Both BACKWARD and FORWARD         | Safest — both old and new
                   | Only add/remove optional fields   | can coexist indefinitely
───────────────────┼───────────────────────────────────┼─────────────────────────
NONE               | No compatibility checking         | Development only
                   |                                   | NEVER use in production

Upgrade sequence for BACKWARD compatibility:
  1. Register new schema (v2) in Schema Registry
  2. Deploy consumers that handle v2 (with defaults for new fields)
  3. Deploy producers that publish v2
  4. Old messages (v1) still readable by v2 consumers via defaults
```

### Schema Registry CLI Commands

```bash
# Register a schema
curl -X POST "${SCHEMA_REGISTRY_URL}/subjects/orders-value/versions" \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"schema": "{\"type\":\"record\",\"name\":\"Order\",\"fields\":[...]}"}'

# Check compatibility before registering
curl -X POST "${SCHEMA_REGISTRY_URL}/compatibility/subjects/orders-value/versions/latest" \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"schema": "{...new schema...}"}'
# Returns: {"is_compatible": true}

# Set compatibility mode
curl -X PUT "${SCHEMA_REGISTRY_URL}/config/orders-value" \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"compatibility": "BACKWARD"}'

# List all versions for a subject
curl "${SCHEMA_REGISTRY_URL}/subjects/orders-value/versions"
```

### Gotchas
- **auto.register.schemas=true in production is dangerous**: Any producer can register any schema, including incompatible ones. Disable auto-registration in production and register schemas via CI/CD pipeline with compatibility checks.
- **Removing a required field is a breaking change**: In BACKWARD mode, removing a field that old consumers expect breaks them. In FORWARD mode, adding a required field (no default) breaks old consumers. Use FULL compatibility to prevent both.
- **Union types order matters**: In Avro, `["null", "string"]` and `["string", "null"]` are different schemas. Changing the order is a breaking change. Always put `null` first for optional fields.
- **DataWeave Avro handling**: When the Kafka consumer returns Avro-decoded data, DataWeave sees it as a Java GenericRecord. Use `payload.fieldName` syntax. If a field is missing (v1 message read with v2 schema), Avro returns the default value, not null. If no default is defined, deserialization fails.
- **Schema Registry is a single point of failure**: If the registry is down, producers with `auto.register.schemas=true` cannot publish new schemas. Cache TTL for resolved schemas is 300 seconds by default. During an outage longer than the cache TTL, both producers and consumers fail.
- **Subject naming strategy matters**: `TopicNameStrategy` uses `<topic>-value` as the subject. `RecordNameStrategy` uses `<namespace>.<name>`. If you share a topic across different event types (not recommended), use `RecordNameStrategy`. Otherwise, stick with `TopicNameStrategy`.
- **Confluent vs Apicurio**: MuleSoft works with both Confluent Schema Registry and Red Hat Apicurio Registry. The serializer class names differ. Confluent: `io.confluent.kafka.serializers.*`, Apicurio: `io.apicurio.registry.serde.*`.

### Testing

```xml
<munit:test name="test-schema-v1-v2-compatibility"
    description="Consumer handles both v1 and v2 messages">

    <munit:execution>
        <!-- Simulate v1 message (no region/priority fields) -->
        <set-payload value='#[output application/json --- {
            orderId: "ORD-001",
            customerId: "CUST-100",
            amount: 99.99,
            currency: "USD",
            createdAt: 1709136000000
        }]' />
        <flow-ref name="consume-orders-multi-version" />
    </munit:execution>

    <munit:validation>
        <!-- Verify defaults were applied for missing v2 fields -->
        <munit-tools:assert-that
            expression="#[payload.region]"
            is="#[MunitTools::equalTo('US')]" />
        <munit-tools:assert-that
            expression="#[payload.priority]"
            is="#[MunitTools::equalTo('NORMAL')]" />
    </munit:validation>
</munit:test>
```

### Related Recipes
- [Kafka Exactly-Once](../kafka-exactly-once/) -- exactly-once semantics with Avro-encoded messages
- [Kafka Rebalance Handling](../kafka-rebalance-handling/) -- schema changes during rolling deployments
- [Avro Schema Validation](../../dataweave/patterns/avro-schema-validation/) -- DataWeave Avro validation patterns
