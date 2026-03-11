/**
 * Pattern: HMAC Signature
 * Category: Security & Encoding
 * Difficulty: Advanced
 * Description: Generate HMAC-SHA256 signatures for webhook verification,
 * API request signing, and message integrity validation. Used by Stripe,
 * GitHub, Slack, and many other webhook providers.
 *
 * Input (application/json):
 * {
 *   "webhookBody": "{\"event\":\"order.created\",\"id\":\"evt_123\"}",
 *   "secret": "whsec_abc123",
 *   "receivedSignature": "sha256=a1b2c3d4e5f6",
 *   "timestamp": "1700000000"
 * }
 *
 * Output (application/json):
 * {
 * "signature": "sha256=<computed_hmac_hex>",
 * "signedPayload": "1708300000.{\"event\":\"payment.completed\",\"amount\":99.99}",
 * "isValid": false
 * }
 */
%dw 2.0
import dw::Crypto
output application/json
var signedPayload = "$(payload.timestamp).$(payload.webhookBody)"
var hmacBytes = Crypto::HMACWith(signedPayload as Binary, payload.secret as Binary, "HmacSHA256")
var hmacHex = lower(hmacBytes reduce (byte, acc = "") -> acc ++ (byte as String {format: "%02x"}))
var computedSig = "sha256=$(hmacHex)"
---
{ signature: computedSig, isValid: computedSig == payload.receivedSignature }
