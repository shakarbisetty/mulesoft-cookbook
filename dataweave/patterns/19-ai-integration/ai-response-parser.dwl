/**
 * Pattern: AI/LLM Response Parser
 * Category: AI Integration
 * Difficulty: Intermediate
 * Description: Parse and validate unstructured LLM responses into typed
 * objects. Handles JSON in markdown fences, partial JSON, hallucinated
 * fields, and missing required keys. Essential for production AI pipelines
 * where LLM output must flow into downstream systems.
 *
 * Input (application/json):
 * {
 *   "rawResponse": "Here is my analysis:\n```json\n{\"ranking\": [\"TK-101\"], \"summary\": \"Timeout is critical.\"}\n```\nLet me know.",
 *   "requiredKeys": [
 *     "ranking",
 *     "summary"
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "parsed": {
 * "priorityRanking": ["TK-101", "TK-098", "TK-095"],
 * "analyses": [{"ticketId": "TK-101", "rootCause": "Connection pool exhaustion under load", "action": "Increase pool size and add circuit breaker"}],
 * "summary": "API timeout is the critical issue."
 * },
 * "valid": true,
 * "missingKeys": [],
 * "parseMethod": "markdown_fence"
 * }
 */
%dw 2.0
import try from dw::Runtime
output application/json
var raw = payload.rawResponse
var fenceMatch = raw match /(?s)```(?:json)?\s*(\{.*?\})\s*```/
var jsonStr = if (fenceMatch[1]?) fenceMatch[1] else raw
var parsed = try(() -> read(jsonStr, "application/json"))
var keys = if (parsed.success) (parsed.result pluck $$) else []
var missing = payload.requiredKeys filter (k) -> !(keys contains k)
---
{
  parsed: if (parsed.success) parsed.result else null,
  valid: parsed.success and isEmpty(missing),
  missingKeys: missing
}
