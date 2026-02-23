/**
 * Pattern: AES Encryption and Decryption
 * Category: Security & Encoding
 * Difficulty: Advanced
 *
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
 *   "operation": "encrypt"
 * }
 *
 * Output (application/json):
 * {
 *   "encryptedData": {
 *     "ssn": "<base64_encrypted_value>",
 *     "creditCard": "<base64_encrypted_value>",
 *     "accountNumber": "<base64_encrypted_value>"
 *   },
 *   "algorithm": "AES/CBC/PKCS5Padding",
 *   "keyRef": "vault:encryption-key"
 * }
 */
%dw 2.0
import dw::Crypto
output application/json

// Key should come from a secure vault, never hardcoded
// In production: vars.encryptionKey from Mule Secure Properties
var encryptionKey = vars.encryptionKey default "AES-256-KEY-HERE"

fun encryptField(value: String): String =
    Crypto::encrypt(
        value as Binary {encoding: "UTF-8"},
        encryptionKey as Binary {encoding: "UTF-8"},
        "AES/CBC/PKCS5Padding"
    ) as String {class: "byte[]"} then toBase64($)

fun decryptField(encrypted: String): String =
    Crypto::decrypt(
        fromBase64(encrypted) as Binary,
        encryptionKey as Binary {encoding: "UTF-8"},
        "AES/CBC/PKCS5Padding"
    ) as String {encoding: "UTF-8"}
---
if (payload.operation == "encrypt")
    {
        encryptedData: payload.sensitiveData mapObject (value, key) ->
            {(key): encryptField(value as String)},
        algorithm: "AES/CBC/PKCS5Padding",
        keyRef: "vault:encryption-key"
    }
else
    {
        decryptedData: payload.sensitiveData mapObject (value, key) ->
            {(key): decryptField(value as String)}
    }

// Alternative 1 — selective field encryption (only PII fields):
// var piiFields = ["ssn", "creditCard", "accountNumber"]
// payload mapObject (v, k) ->
//     if (piiFields contains (k as String)) {(k): encryptField(v)} else {(k): v}

// Alternative 2 — GCM mode (includes authentication tag):
// Crypto::encrypt(data, key, "AES/GCM/NoPadding")
