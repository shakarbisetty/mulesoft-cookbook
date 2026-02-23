/**
 * Pattern: JWT Token Decode
 * Category: Security & Encoding
 * Difficulty: Intermediate
 *
 * Description: Parse a JWT (JSON Web Token) to extract header and payload
 * claims without signature verification. Useful for logging, routing based
 * on claims, or extracting user context in integration flows.
 *
 * NOTE: This does NOT verify the signature. Verification should be done
 * by your API gateway or security policy, not in DataWeave.
 *
 * Input (application/json):
 * {
 *   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwicm9sZSI6ImFkbWluIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE3MzkwMDAwMDB9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
 * }
 *
 * Output (application/json):
 * {
 *   "header": {
 *     "alg": "HS256",
 *     "typ": "JWT"
 *   },
 *   "payload": {
 *     "sub": "1234567890",
 *     "name": "John Doe",
 *     "role": "admin",
 *     "iat": 1516239022,
 *     "exp": 1739000000
 *   },
 *   "isExpired": true,
 *   "subject": "1234567890"
 * }
 */
%dw 2.0
import * from dw::core::Binaries
output application/json

fun decodeJwtPart(part: String): Object =
    read(fromBase64(part) as String {encoding: "UTF-8"}, "application/json")

var parts = payload.token splitBy "."
var jwtHeader = decodeJwtPart(parts[0])
var jwtPayload = decodeJwtPart(parts[1])
---
{
    header: jwtHeader,
    payload: jwtPayload,
    isExpired: if (jwtPayload.exp != null)
                  jwtPayload.exp < (now() as Number {unit: "seconds"})
               else false,
    subject: jwtPayload.sub
}

// Alternative — extract a single claim:
// var claims = decodeJwtPart((payload.token splitBy ".")[1])
// ---
// claims.role
