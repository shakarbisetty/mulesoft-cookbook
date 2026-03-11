/**
 * Pattern: Retry with Backoff Config
 * Category: Error Handling
 * Difficulty: Intermediate
 * Description: Build retry policy configuration in DataWeave for
 * transient error recovery. Calculate exponential backoff delays,
 * determine if an error is retryable, and track retry state.
 *
 * Input (application/json):
 * {
 *   "error": {
 *     "type": "HTTP:TIMEOUT",
 *     "message": "Request timed out"
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
 * "shouldRetry": true,
 * "currentAttempt": 2,
 * "nextAttempt": 3,
 * "remainingRetries": 3,
 * "delayMs": 4000,
 * "delayFormatted": "4.0s",
 * "retryAfter": "2026-02-18T10:30:04Z",
 * "isRetryableError": true,
 * "reason": "HTTP:TIMEOUT is a transient error"
 * }
 */
%dw 2.0
output application/json
var retryableErrors = ["HTTP:TIMEOUT","HTTP:CONNECTIVITY","HTTP:SERVICE_UNAVAILABLE"]
var attempt = payload.retryState.attempt
var maxRetries = payload.retryState.maxRetries
var baseDelay = payload.retryState.baseDelayMs
var maxDelay = payload.retryState.maxDelayMs
var exponentialDelay = min([baseDelay * (2 pow attempt), maxDelay]) as Number
var isRetryable = retryableErrors contains payload.error."type"
var shouldRetry = isRetryable and (attempt < maxRetries)
---
{ shouldRetry: shouldRetry, delayMs: exponentialDelay, nextAttempt: attempt + 1, reason: payload.error."type" ++ if (shouldRetry) " is retryable" else " is not retryable" }
