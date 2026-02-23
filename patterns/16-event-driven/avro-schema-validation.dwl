/**
 * Pattern: Avro Schema Type Validation
 * Category: Event-Driven
 * Difficulty: Advanced
 *
 * Description: Import Avro schemas as DataWeave types using the avroschema!
 * module loader (DW 2.8). Validates payloads against Avro .avsc schema files
 * at transformation time — critical for Kafka producers ensuring messages
 * match the Schema Registry contract.
 *
 * Input (application/json):
 * {
 *   "userId": "usr-12345",
 *   "eventType": "ORDER_PLACED",
 *   "timestamp": 1708300000,
 *   "payload": {
 *     "orderId": "ORD-98765",
 *     "amount": 149.99,
 *     "currency": "USD",
 *     "items": 3
 *   }
 * }
 *
 * Output (application/avro):
 * {
 *   "userId": "usr-12345",
 *   "eventType": "ORDER_PLACED",
 *   "timestamp": 1708300000,
 *   "payload": "{\"orderId\":\"ORD-98765\",\"amount\":149.99,\"currency\":\"USD\",\"items\":3}"
 * }
 */
%dw 2.0

// Import the Avro schema as a DataWeave type
// Assumes: src/main/resources/schemas/OrderEvent.avsc
// import * from avroschema!schemas::OrderEvent

output application/avro schemaUrl="classpath://schemas/OrderEvent.avsc"
---
{
    userId: payload.userId,
    eventType: payload.eventType,
    timestamp: payload.timestamp,
    payload: write(payload.payload, "application/json")
}

// Alternative 1 — validate before producing (type check with try):
// import * from dw::Runtime
// var validated = try(() -> payload as OrderEvent)
// ---
// if (validated.success) validated.result
// else logError("Schema validation failed: $(validated.error.message)")

// Alternative 2 — enum validation for eventType:
// var validTypes = ["ORDER_PLACED", "ORDER_SHIPPED", "ORDER_CANCELLED"]
// ---
// if (validTypes contains payload.eventType) payload
// else fail("Invalid eventType: $(payload.eventType)")

// Alternative 3 — read Avro binary back to JSON:
// %dw 2.0
// input payload application/avro schemaUrl="classpath://schemas/OrderEvent.avsc"
// output application/json
// ---
// payload
