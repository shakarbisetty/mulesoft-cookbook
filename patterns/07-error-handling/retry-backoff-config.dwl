/**
 * Pattern: Retry with Backoff Config
 * Category: Error Handling
 * Difficulty: Intermediate
 *
 * Description: Build retry policy configuration in DataWeave for
 * transient error recovery. Calculate exponential backoff delays,
 * determine if an error is retryable, and track retry state.
 *
 * Input (application/json):
 * {
 *   "error": {
 *     "type": "HTTP:TIMEOUT",
 *     "description": "Connection timed out after 30000ms",
 *     "statusCode": 504
 *   },
 *   "retryState": {
 *     "attempt": 2,
 *     "maxRetries": 5,
 *     "baseDelayMs": 1000,
 *     "maxDelayMs": 30000
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "shouldRetry": true,
 *   "currentAttempt": 2,
 *   "nextAttempt": 3,
 *   "remainingRetries": 3,
 *   "delayMs": 4000,
 *   "delayFormatted": "4.0s",
 *   "retryAfter": "2026-02-18T10:30:04Z",
 *   "isRetryableError": true,
 *   "reason": "HTTP:TIMEOUT is a transient error"
 * }
 */
%dw 2.0
output application/json

// Errors that are safe to retry (transient)
var retryableErrors = [
    "HTTP:TIMEOUT",
    "HTTP:CONNECTIVITY",
    "HTTP:SERVICE_UNAVAILABLE",
    "MULE:RETRY_EXHAUSTED",
    "DB:CONNECTIVITY",
    "JMS:CONNECTIVITY",
    "FTP:CONNECTIVITY"
]

var retryableStatusCodes = [408, 429, 500, 502, 503, 504]

var errorType = payload.error."type"
var statusCode = payload.error.statusCode
var attempt = payload.retryState.attempt
var maxRetries = payload.retryState.maxRetries
var baseDelay = payload.retryState.baseDelayMs
var maxDelay = payload.retryState.maxDelayMs

// Exponential backoff: delay = base * 2^attempt (capped at maxDelay)
// With jitter: add random 0-500ms to prevent thundering herd
var exponentialDelay = min([baseDelay * (2 pow attempt), maxDelay]) as Number

var isRetryable = (retryableErrors contains errorType)
    or (retryableStatusCodes contains statusCode)

var shouldRetry = isRetryable and (attempt < maxRetries)
---
{
    shouldRetry: shouldRetry,
    currentAttempt: attempt,
    nextAttempt: attempt + 1,
    remainingRetries: max([maxRetries - attempt, 0]),
    delayMs: if (shouldRetry) exponentialDelay else 0,
    delayFormatted: "$(exponentialDelay / 1000)s",
    isRetryableError: isRetryable,
    reason: if (!isRetryable) "$(errorType) is not a retryable error"
            else if (attempt >= maxRetries) "Max retries ($(maxRetries)) exhausted"
            else "$(errorType) is a transient error"
}
