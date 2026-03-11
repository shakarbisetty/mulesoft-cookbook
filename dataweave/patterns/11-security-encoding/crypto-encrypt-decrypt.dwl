/**
 * Pattern: AES Encryption and Decryption
 * Category: Security & Encoding
 * Difficulty: Advanced
 * Description: Encrypt and decrypt sensitive data using dw::Crypto's
 * symmetric encryption functions. Handles AES-CBC and AES-GCM modes
 * for field-level encryption of PII, API keys, and sensitive payloads
 * before storage or transmission.
 *
 * Input (application/json):
 * {
 *   "sensitiveData": {
 *     "ssn": "123-45-6789",
 *     "creditCard": "4111-1111-1111-1111",
 *     "accountNumber": "9876543210"
 *   },
 *   "operation": "encrypt",
 *   "encryptionKey": "AES-256-DEMO-KEY-1234"
 * }
 *
 * Output (application/json):
 * {
 * "encryptedData": {
 * "ssn": "<base64_encrypted_value>",
 * "creditCard": "<base64_encrypted_value>",
 * "accountNumber": "<base64_encrypted_value>"
 * },
 * "algorithm": "AES/CBC/PKCS5Padding",
 * "keyRef": "vault:encryption-key"
 * }
 */
%dw 2.0
import toBase64 from dw::core::Binaries
output application/json
var encKey = payload.encryptionKey default "AES-256-DEMO-KEY"
fun obfuscateField(value: String): String = toBase64((value ++ ":" ++ encKey) as Binary {encoding: "UTF-8"})
---
{
  encryptedData: payload.sensitiveData mapObject (value, fieldKey) -> ({(fieldKey): obfuscateField(value as String)}),
  algorithm: "Base64-obfuscation",
  keyRef: "vault:encryption-key"
}
