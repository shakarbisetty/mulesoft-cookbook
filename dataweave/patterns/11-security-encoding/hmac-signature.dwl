/**
 * Pattern: HMAC Signature
 * Category: Security & Encoding
 * Difficulty: Advanced
 *
 * Description: Generate HMAC-SHA256 signatures for webhook verification,
 * API request signing, and message integrity validation. Used by Stripe,
 * GitHub, Slack, and many other webhook providers.
 *
 * Input (application/json):
 * {
 *   "webhookBody": "{\"event\":\"payment.completed\",\"amount\":99.99}",
 *   "secret": "whsec_MIGfMA0GCSqGSIb3DQEBAQUAA4",
 *   "receivedSignature": "sha256=a]b2c3d4e5f6...",
 *   "timestamp": "1708300000"
 * }
 *
 * Output (application/json):
 * {
 *   "signature": "sha256=<computed_hmac_hex>",
 *   "signedPayload": "1708300000.{\"event\":\"payment.completed\",\"amount\":99.99}",
 *   "isValid": false
 * }
 */
%dw 2.0
import dw::Crypto
output application/json

// Build the signed payload (Stripe-style: timestamp.body)
var signedPayload = "$(payload.timestamp).$(payload.webhookBody)"

// Compute HMAC-SHA256
var hmacBytes = Crypto::HMACWith(
    signedPayload as Binary {encoding: "UTF-8"},
    payload.secret as Binary {encoding: "UTF-8"},
    "HmacSHA256"
)

// Convert to hex string
var hmacHex = lower(hmacBytes reduce (byte, acc = "") ->
    acc ++ (byte as String {format: "%02x"}))

var computedSignature = "sha256=$(hmacHex)"
---
{
    signature: computedSignature,
    signedPayload: signedPayload,
    isValid: computedSignature == payload.receivedSignature
}

// Alternative — simple HMAC for API signing:
// Crypto::HMACWith(payload as Binary, vars.apiSecret as Binary, "HmacSHA256")
