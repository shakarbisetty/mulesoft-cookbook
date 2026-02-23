/**
 * Pattern: AI/LLM Response Parser
 * Category: AI Integration
 * Difficulty: Intermediate
 *
 * Description: Parse and validate unstructured LLM responses into typed
 * objects. Handles JSON in markdown fences, partial JSON, hallucinated
 * fields, and missing required keys. Essential for production AI pipelines
 * where LLM output must flow into downstream systems.
 *
 * Input (application/json):
 * {
 *   "rawResponse": "Here's my analysis:\n\n```json\n{\"priorityRanking\": [\"TK-101\", \"TK-098\", \"TK-095\"], \"analyses\": [{\"ticketId\": \"TK-101\", \"rootCause\": \"Connection pool exhaustion under load\", \"action\": \"Increase pool size and add circuit breaker\"}], \"summary\": \"API timeout is the critical issue.\"}\n```\n\nLet me know if you need more details.",
 *   "requiredKeys": ["priorityRanking", "analyses", "summary"]
 * }
 *
 * Output (application/json):
 * {
 *   "parsed": {
 *     "priorityRanking": ["TK-101", "TK-098", "TK-095"],
 *     "analyses": [{"ticketId": "TK-101", "rootCause": "Connection pool exhaustion under load", "action": "Increase pool size and add circuit breaker"}],
 *     "summary": "API timeout is the critical issue."
 *   },
 *   "valid": true,
 *   "missingKeys": [],
 *   "parseMethod": "markdown_fence"
 * }
 */
%dw 2.0
import try from dw::Runtime
output application/json

// Step 1: Extract JSON from markdown fences or raw text
var raw = payload.rawResponse

var fenceMatch = raw match /(?s)```(?:json)?\s*(\{.*?\})\s*```/
var jsonStr = if (fenceMatch[1]?) fenceMatch[1]
    else do {
        // Fallback: find first { ... } block
        var braceMatch = raw match /(?s)(\{.*\})/
        ---
        if (braceMatch[1]?) braceMatch[1] else ""
    }

var parseMethod = if (fenceMatch[1]?) "markdown_fence"
    else if (jsonStr != "") "brace_extraction"
    else "failed"

// Step 2: Parse the JSON safely
var parsed = try(() -> read(jsonStr, "application/json"))

// Step 3: Validate required keys
var result = if (parsed.success) parsed.result else {}
var presentKeys = if (parsed.success) (result pluck $$) map (k) -> k as String else []
var missingKeys = payload.requiredKeys default [] filter (k) -> !(presentKeys contains k)
---
{
    parsed: if (parsed.success) result else null,
    valid: parsed.success and isEmpty(missingKeys),
    missingKeys: missingKeys,
    parseMethod: parseMethod
}

// Alternative 1 — extract just a single field with default:
// var summary = if (parsed.success) parsed.result.summary default "No summary" else "Parse failed"

// Alternative 2 — retry-safe wrapper (return original on failure):
// if (parsed.success) parsed.result else {error: "LLM response was not valid JSON", raw: raw}

// Alternative 3 — strip common LLM artifacts before parsing:
// var cleaned = raw replace /^(Here's|Sure|Certainly).*?:\s*/i with ""
//     replace /\n\nLet me know.*$/i with ""
