/**
 * Pattern: Error Envelope
 * Category: API Response Patterns
 * Difficulty: Beginner
 * Description: Build standardized error responses following RFC 7807
 * (Problem Details for HTTP APIs). Provides consistent error format
 * across all API endpoints for better client-side error handling.
 *
 * Input (application/json):
 * {
 *   "error": {
 *     "errorType": {
 *       "identifier": "HTTP:NOT_FOUND"
 *     },
 *     "description": "Customer CUST-999 not found"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "type": "https://api.example.com/errors/validation",
 * "title": "Validation Error",
 * "status": 400,
 * "detail": "The 'email' field is not a valid email address",
 * "instance": "/api/v1/customers",
 * "timestamp": "2026-02-18T10:30:00Z",
 * "correlationId": "abc-123-def",
 * "errors": [
 * { "field": "email", "message": "Invalid email format" },
 * { "field": "phone", "message": "Phone number is required" }
 * ]
 * }
 */
%dw 2.0
output application/json
var errorMapping = {
    "HTTP:BAD_REQUEST": { status: 400, title: "Bad Request", "type": "client-error" },
    "HTTP:UNAUTHORIZED": { status: 401, title: "Unauthorized", "type": "authentication" },
    "HTTP:NOT_FOUND": { status: 404, title: "Not Found", "type": "not-found" },
    "HTTP:TIMEOUT": { status: 504, title: "Gateway Timeout", "type": "timeout" } }
var errorInfo = errorMapping[payload.error.errorType.identifier] default { status: 500, title: "Internal Server Error", "type": "server-error" }
---
{ "type": "https://api.example.com/errors/$(errorInfo.'type')", title: errorInfo.title, status: errorInfo.status, detail: payload.error.description, timestamp: now() }
