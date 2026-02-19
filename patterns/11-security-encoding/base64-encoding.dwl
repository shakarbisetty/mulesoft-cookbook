/**
 * Pattern: Base64 Encode/Decode
 * Category: Security & Encoding
 * Difficulty: Beginner
 *
 * Description: Encode and decode binary data using Base64. Common for
 * file attachments, basic auth headers, and binary payload transport.
 *
 * Input (application/json):
 * {
 *   "username": "admin",
 *   "password": "secret123",
 *   "fileContent": "Hello, World!",
 *   "encodedData": "SGVsbG8sIFdvcmxkIQ=="
 * }
 *
 * Output (application/json):
 * {
 *   "basicAuthHeader": "Authorization: Basic YWRtaW46c2VjcmV0MTIz",
 *   "encodedFile": "SGVsbG8sIFdvcmxkIQ==",
 *   "decodedData": "Hello, World!",
 *   "roundTrip": "Hello, World!"
 * }
 */
%dw 2.0
import * from dw::core::Binaries
output application/json
---
{
    // Encode credentials for Basic Auth
    basicAuthHeader: "Authorization: Basic $(toBase64("$(payload.username):$(payload.password)" as Binary {encoding: "UTF-8"}))",

    // Encode a string (e.g., file content) to Base64
    encodedFile: toBase64(payload.fileContent as Binary {encoding: "UTF-8"}),

    // Decode Base64 back to string
    decodedData: fromBase64(payload.encodedData) as String {encoding: "UTF-8"},

    // Round-trip: encode then decode
    roundTrip: fromBase64(
        toBase64(payload.fileContent as Binary {encoding: "UTF-8"})
    ) as String {encoding: "UTF-8"}
}

// Alternative — using write/read for binary payloads:
// toBase64(write(payload, "application/json") as Binary)
