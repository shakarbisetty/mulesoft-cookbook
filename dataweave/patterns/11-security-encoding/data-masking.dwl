/**
 * Pattern: Data Masking
 * Category: Security & Encoding
 * Difficulty: Intermediate
 *
 * Description: Mask PII (Personally Identifiable Information) in payloads
 * for logging, audit trails, and non-production environments. Covers SSN,
 * credit cards, phone numbers, emails, and custom field masking.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "John Doe",
 *     "ssn": "123-45-6789",
 *     "creditCard": "4532015112830366",
 *     "phone": "+1-555-867-5309",
 *     "email": "john.doe@example.com",
 *     "dob": "1990-03-15"
 *   },
 *   "order": {
 *     "id": "ORD-12345",
 *     "total": 299.99
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "customer": {
 *     "name": "John Doe",
 *     "ssn": "***-**-6789",
 *     "creditCard": "************0366",
 *     "phone": "***-***-5309",
 *     "email": "j******e@example.com",
 *     "dob": "****-**-15"
 *   },
 *   "order": {
 *     "id": "ORD-12345",
 *     "total": 299.99
 *   }
 * }
 */
%dw 2.0
output application/json

// Mask all but last N characters
fun maskRight(s: String, visible: Number): String =
    if (sizeOf(s) <= visible) s
    else ("*" * (sizeOf(s) - visible)) ++ s[(sizeOf(s) - visible) to -1]

// Mask SSN: show last 4 digits
fun maskSSN(ssn: String): String =
    ssn replace /^\d{3}-\d{2}/ with "***-**"

// Mask credit card: show last 4 digits
fun maskCreditCard(cc: String): String =
    maskRight(cc replace /[^0-9]/ with "", 4)

// Mask phone: show last 4 digits
fun maskPhone(phone: String): String =
    phone replace /\d(?=\d{4})/ with "*"

// Mask email: show first and last char of local part
fun maskEmail(email: String): String = do {
    var parts = email splitBy "@"
    var local = parts[0]
    var masked = if (sizeOf(local) <= 2) local
                 else "$(local[0])$("*" * (sizeOf(local) - 2))$(local[-1 to -1])"
    ---
    "$(masked)@$(parts[1])"
}

// Mask date: show only day
fun maskDate(d: String): String =
    d replace /^\d{4}-\d{2}/ with "****-**"
---
{
    customer: {
        name: payload.customer.name,
        ssn: maskSSN(payload.customer.ssn),
        creditCard: maskCreditCard(payload.customer.creditCard),
        phone: maskPhone(payload.customer.phone),
        email: maskEmail(payload.customer.email),
        dob: maskDate(payload.customer.dob)
    },
    order: payload.order
}

// Alternative — generic field-based masking:
// var sensitiveFields = ["ssn", "creditCard", "phone"]
// payload mapObject (value, key) ->
//     if (sensitiveFields contains (key as String))
//         { (key): maskRight(value as String, 4) }
//     else { (key): value }
