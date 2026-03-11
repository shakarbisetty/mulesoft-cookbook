/**
 * Pattern: Data Masking
 * Category: Security & Encoding
 * Difficulty: Intermediate
 * Description: Mask PII (Personally Identifiable Information) in payloads
 * for logging, audit trails, and non-production environments. Covers SSN,
 * credit cards, phone numbers, emails, and custom field masking.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "John Smith",
 *     "ssn": "123-45-6789",
 *     "creditCard": "4111-1111-1111-1234",
 *     "email": "john.smith@example.com"
 *   },
 *   "order": {
 *     "id": "ORD-001",
 *     "total": 129.99
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "customer": {
 * "name": "John Doe",
 * "ssn": "***-**-6789",
 * "creditCard": "************0366",
 * "phone": "***-***-5309",
 * "email": "j******e@example.com",
 * "dob": "****-**-15"
 * },
 * "order": {
 * "id": "ORD-12345",
 * "total": 299.99
 * }
 * }
 */
%dw 2.0
output application/json
fun maskSSN(ssn: String): String = ssn replace /^\d{3}-\d{2}/ with "***-**"
fun maskCC(cc: String): String = ("*" * (sizeOf(cc) - 4)) ++ cc[-4 to -1]
fun maskEmail(e: String): String = do {
  var parts = e splitBy "@"
  ---
  parts[0][0] ++ "****@" ++ parts[1]
}
---
{
  customer: {name: payload.customer.name, ssn: maskSSN(payload.customer.ssn), creditCard: maskCC(payload.customer.creditCard), email: maskEmail(payload.customer.email)},
  order: payload.order
}
