/**
 * Pattern: Error Envelope
 * Category: API Response Patterns
 * Difficulty: Beginner
 *
 * Description: Build standardized error responses following RFC 7807
 * (Problem Details for HTTP APIs). Provides consistent error format
 * across all API endpoints for better client-side error handling.
 *
 * Input: error object from Mule error handler
 *
 * Output (application/json):
 * {
 *   "type": "https://api.example.com/errors/validation",
 *   "title": "Validation Error",
 *   "status": 400,
 *   "detail": "The 'email' field is not a valid email address",
 *   "instance": "/api/v1/customers",
 *   "timestamp": "2026-02-18T10:30:00Z",
 *   "correlationId": "abc-123-def",
 *   "errors": [
 *     { "field": "email", "message": "Invalid email format" },
 *     { "field": "phone", "message": "Phone number is required" }
 *   ]
 * }
 */
%dw 2.0
output application/json

// Map Mule error types to HTTP status codes and titles
var errorMapping = {
    "HTTP:BAD_REQUEST":      { status: 400, title: "Bad Request", "type": "client-error" },
    "HTTP:UNAUTHORIZED":     { status: 401, title: "Unauthorized", "type": "authentication" },
    "HTTP:FORBIDDEN":        { status: 403, title: "Forbidden", "type": "authorization" },
    "HTTP:NOT_FOUND":        { status: 404, title: "Not Found", "type": "not-found" },
    "HTTP:METHOD_NOT_ALLOWED": { status: 405, title: "Method Not Allowed", "type": "client-error" },
    "HTTP:TIMEOUT":          { status: 504, title: "Gateway Timeout", "type": "timeout" },
    "HTTP:CONNECTIVITY":     { status: 503, title: "Service Unavailable", "type": "connectivity" },
    "MULE:EXPRESSION":       { status: 400, title: "Validation Error", "type": "validation" },
    "APIKIT:BAD_REQUEST":    { status: 400, title: "Bad Request", "type": "validation" },
    "APIKIT:NOT_FOUND":      { status: 404, title: "Resource Not Found", "type": "not-found" }
}

var errorInfo = errorMapping[error.errorType.identifier]
    default { status: 500, title: "Internal Server Error", "type": "system" }
---
{
    "type": "https://api.example.com/errors/$(errorInfo.'type')",
    title: errorInfo.title,
    status: errorInfo.status,
    detail: error.description,
    instance: attributes.requestUri default "unknown",
    timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssZ"},
    correlationId: correlationId,
    (errors: error.cause.description) if error.cause != null
}

// Alternative — simple error without RFC 7807:
// {
//     error: { code: 400, message: error.description },
//     correlationId: correlationId
// }
