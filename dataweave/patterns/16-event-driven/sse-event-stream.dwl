/**
 * Pattern: SSE Event Stream Parser
 * Category: Event-Driven
 * Difficulty: Intermediate
 * Description: Parse and generate Server-Sent Events (SSE) using the native
 * text/event-stream format introduced in DataWeave 2.9. Handles real-time
 * streaming responses from AI/LLM APIs, live dashboards, and push notifications.
 *
 * Input (application/json):
 * {
 *   "events": [
 *     "data: {\"token\": \"Hello\"}",
 *     "data: {\"token\": \" world\"}",
 *     "data: {\"token\": \"!\"}",
 *     "data: [DONE]"
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "tokens": ["Hello", " world", "!"],
 * "fullText": "Hello world!",
 * "eventCount": 3
 * }
 */
%dw 2.0
output application/json
var events = payload.events filter (e) -> e != "data: [DONE]"
var parsed = events map (e) -> read(e[6 to -1], "application/json")
---
{tokens: parsed map $.token, fullText: parsed reduce (e, acc = "") -> acc ++ e.token, eventCount: sizeOf(parsed)}
