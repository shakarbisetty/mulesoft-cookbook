/**
 * Pattern: Error Response Builder
 * Category: Error Handling
 * Difficulty: Intermediate
 *
 * Description: Build standardized error response payloads for REST APIs. Use
 * in error handlers to return consistent, well-structured error JSON/XML
 * that includes status code, error type, message, correlation ID, and
 * timestamp. Follows common API error response conventions.
 *
 * Input (application/json):
 * {
 *   "httpStatus": 422,
 *   "errorType": "VALIDATION_ERROR",
 *   "errorMessage": "Required field 'email' is missing",
 *   "correlationId": "abc-123-def-456",
 *   "resource": "/api/v1/customers",
 *   "method": "POST",
 *   "validationErrors": [
 *     {"field": "email", "message": "Field is required"},
 *     {"field": "phone", "message": "Invalid phone format: must match +X-XXX-XXX-XXXX"}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "error": {
 *     "status": 422,
 *     "type": "VALIDATION_ERROR",
 *     "message": "Required field 'email' is missing",
 *     "timestamp": "2026-02-15T12:00:00Z",
 *     "correlationId": "abc-123-def-456",
 *     "path": "POST /api/v1/customers",
 *     "details": [
 *       {"field": "email", "message": "Field is required"},
 *       {"field": "phone", "message": "Invalid phone format: must match +X-XXX-XXX-XXXX"}
 *     ]
 *   }
 * }
 */
%dw 2.0
output application/json

fun buildErrorResponse(
    status: Number,
    errorType: String,
    message: String,
    correlationId: String,
    path: String,
    details: Array = []
) = {
    error: {
        status: status,
        "type": errorType,
        message: message,
        timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"},
        correlationId: correlationId,
        path: path,
        (details: details) if (sizeOf(details) > 0)
    }
}
---
buildErrorResponse(
    payload.httpStatus,
    payload.errorType,
    payload.errorMessage,
    payload.correlationId,
    "$(payload.method) $(payload.resource)",
    payload.validationErrors default []
)

// Alternative 1 — map Mule error types to HTTP status codes:
// var errorMap = {
//     "HTTP:UNAUTHORIZED": 401,
//     "HTTP:FORBIDDEN": 403,
//     "HTTP:NOT_FOUND": 404,
//     "HTTP:METHOD_NOT_ALLOWED": 405,
//     "HTTP:TIMEOUT": 408,
//     "VALIDATION:INVALID_PAYLOAD": 422,
//     "HTTP:INTERNAL_SERVER_ERROR": 500,
//     "HTTP:CONNECTIVITY": 503
// }
// ---
// errorMap[error.errorType] default 500

// Alternative 2 — error response without sensitive details (production):
// {
//     error: {
//         status: 500,
//         message: "An internal error occurred. Please contact support.",
//         correlationId: vars.correlationId,
//         timestamp: now()
//     }
// }
