/**
 * Pattern: Error Response Builder
 * Category: Error Handling
 * Difficulty: Intermediate
 * Description: Build standardized error response payloads for REST APIs. Use
 * in error handlers to return consistent, well-structured error JSON/XML
 * that includes status code, error type, message, correlation ID, and
 * timestamp. Follows common API error response conventions.
 *
 * Input (application/json):
 * {
 *   "httpStatus": 422,
 *   "errorType": "VALIDATION_ERROR",
 *   "errorMessage": "Field email is missing",
 *   "correlationId": "abc-123-def-456",
 *   "resource": "/api/v1/customers",
 *   "method": "POST",
 *   "validationErrors": [
 *     {
 *       "field": "email",
 *       "message": "Required"
 *     },
 *     {
 *       "field": "phone",
 *       "message": "Bad format"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "error": {
 * "status": 422,
 * "type": "VALIDATION_ERROR",
 * "message": "Required field 'email' is missing",
 * "timestamp": "2026-02-15T12:00:00Z",
 * "correlationId": "abc-123-def-456",
 * "path": "POST /api/v1/customers",
 * "details": [
 * {"field": "email", "message": "Field is required"},
 * {"field": "phone", "message": "Invalid phone format: must match +X-XXX-XXX-XXXX"}
 * ]
 * }
 * }
 */
%dw 2.0
output application/json
---
{
  error: {
    status: payload.httpStatus,
    "type": payload.errorType,
    message: payload.errorMessage,
    timestamp: now(),
    correlationId: payload.correlationId,
    path: "$(payload.method) $(payload.resource)",
    details: payload.validationErrors default []
  }
}
