/**
 * Pattern: Avro Schema Type Validation
 * Category: Event-Driven
 * Difficulty: Advanced
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
 * Output (application/json):
 * {
 * "userId": "usr-12345",
 * "eventType": "ORDER_PLACED",
 * "timestamp": 1708300000,
 * "payload": "{\"orderId\":\"ORD-98765\",\"amount\":149.99,\"currency\":\"USD\",\"items\":3}"
 * }
 */
%dw 2.0
output application/json
---
{
  userId: payload.userId,
  eventType: payload.eventType,
  timestamp: payload.timestamp,
  payload: write(payload.payload, "application/json")
}
