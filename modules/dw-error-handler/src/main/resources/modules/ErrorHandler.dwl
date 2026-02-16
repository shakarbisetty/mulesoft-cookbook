%dw 2.0

/**
 * Module: ErrorHandler
 * Version: 1.0.0
 *
 * Reusable error handling utility functions for DataWeave 2.x.
 * Provides standardized error response builders for REST and SOAP APIs,
 * error classification, retry detection, sanitization, and correlation.
 *
 * Import with: import modules::ErrorHandler
 *
 * Functions (8):
 *   buildErrorResponse, classifyError, isRetryable, errorToLog,
 *   sanitizeError, wrapWithCorrelation, httpStatusFromError, buildFaultResponse
 */

/**
 * Build a standardized JSON error response.
 * buildErrorResponse(400, "Bad Request", "Field 'email' is required")
 *   -> {error: {code: 400, message: "Bad Request", detail: "Field 'email' is required", timestamp: "..."}}
 */
fun buildErrorResponse(code: Number, msg: String, detail: String): Object =
    {
        error: {
            code: code,
            message: msg,
            detail: detail,
            timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
        }
    }

/**
 * Classify a Mule error object into a category string.
 * Expects the standard Mule error structure with errorType.identifier or description.
 *
 * Categories: VALIDATION, AUTHENTICATION, AUTHORIZATION, NOT_FOUND,
 *             TIMEOUT, CONNECTIVITY, TRANSFORMATION, SYSTEM
 *
 * classifyError({errorType: {identifier: "HTTP:UNAUTHORIZED"}}) -> "AUTHENTICATION"
 */
fun classifyError(error: Object): String =
    do {
        var errorId = upper(error.errorType.identifier default error.errorType default "")
        ---
        if (errorId contains "VALIDATION" or errorId contains "BAD_REQUEST" or errorId contains "EXPRESSION")
            "VALIDATION"
        else if (errorId contains "UNAUTHORIZED" or errorId contains "UNAUTHENTICATED")
            "AUTHENTICATION"
        else if (errorId contains "FORBIDDEN" or errorId contains "ACCESS_DENIED")
            "AUTHORIZATION"
        else if (errorId contains "NOT_FOUND")
            "NOT_FOUND"
        else if (errorId contains "TIMEOUT")
            "TIMEOUT"
        else if (errorId contains "CONNECTIVITY" or errorId contains "CONNECTION_REFUSED" or errorId contains "RETRY_EXHAUSTED")
            "CONNECTIVITY"
        else if (errorId contains "TRANSFORMATION" or errorId contains "MAPPING")
            "TRANSFORMATION"
        else
            "SYSTEM"
    }

/**
 * Determine if an error is transient and worth retrying.
 * Retryable: TIMEOUT, CONNECTIVITY, 429, 502, 503, 504.
 *
 * isRetryable({errorType: {identifier: "HTTP:TIMEOUT"}}) -> true
 * isRetryable({errorType: {identifier: "HTTP:UNAUTHORIZED"}}) -> false
 */
fun isRetryable(error: Object): Boolean =
    do {
        var errorId = upper(error.errorType.identifier default error.errorType default "")
        var statusCode = error.exception.statusCode default error.statusCode default 0
        ---
        (errorId contains "TIMEOUT")
        or (errorId contains "CONNECTIVITY")
        or (errorId contains "RETRY_EXHAUSTED")
        or (errorId contains "CONNECTION_REFUSED")
        or (statusCode == 429)
        or (statusCode == 502)
        or (statusCode == 503)
        or (statusCode == 504)
    }

/**
 * Convert an error object to a sanitized single-line log string.
 * Strips stack traces and sensitive fields, keeps essentials.
 *
 * errorToLog({errorType: {identifier: "HTTP:NOT_FOUND"}, description: "Resource missing"})
 *   -> "ERROR [HTTP:NOT_FOUND] Resource missing"
 */
fun errorToLog(error: Object): String =
    do {
        var errorId = error.errorType.identifier default error.errorType default "UNKNOWN"
        var desc = error.description default error.message default "No description"
        ---
        "ERROR [$(errorId)] $(desc)"
    }

/**
 * Remove sensitive data from an error payload before returning to clients.
 * Strips: stackTrace, exception, cause, internalMessage, childErrors.
 *
 * sanitizeError({message: "Not found", stackTrace: "...", exception: {...}})
 *   -> {message: "Not found"}
 */
fun sanitizeError(error: Object): Object =
    error filterObject ((val, key) ->
        !(["stackTrace", "exception", "cause", "internalMessage", "childErrors", "muleMessage"]
          contains (key as String))
    )

/**
 * Wrap an error object with a correlation ID for distributed tracing.
 *
 * wrapWithCorrelation({error: {code: 500}}, "abc-123")
 *   -> {correlationId: "abc-123", error: {code: 500}}
 */
fun wrapWithCorrelation(error: Object, correlationId: String): Object =
    {correlationId: correlationId} ++ error

/**
 * Map an error classification to an HTTP status code.
 *
 * httpStatusFromError("VALIDATION") -> 400
 * httpStatusFromError("AUTHENTICATION") -> 401
 * httpStatusFromError("NOT_FOUND") -> 404
 */
fun httpStatusFromError(errorType: String): Number =
    do {
        var statusMap = {
            "VALIDATION": 400,
            "AUTHENTICATION": 401,
            "AUTHORIZATION": 403,
            "NOT_FOUND": 404,
            "TIMEOUT": 408,
            "CONNECTIVITY": 503,
            "TRANSFORMATION": 500,
            "SYSTEM": 500
        }
        ---
        statusMap[errorType] default 500
    }

/**
 * Build a SOAP fault response structure.
 *
 * buildFaultResponse("Server", "Internal processing error")
 *   -> {Fault: {faultcode: "Server", faultstring: "Internal processing error", detail: {timestamp: "..."}}}
 */
fun buildFaultResponse(code: String, msg: String): Object =
    {
        Fault: {
            faultcode: code,
            faultstring: msg,
            detail: {
                timestamp: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}
            }
        }
    }
