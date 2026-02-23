/**
 * Pattern: SSE Event Stream Parser
 * Category: Event-Driven
 * Difficulty: Intermediate
 *
 * Description: Parse and generate Server-Sent Events (SSE) using the native
 * text/event-stream format introduced in DataWeave 2.9. Handles real-time
 * streaming responses from AI/LLM APIs, live dashboards, and push notifications.
 *
 * Input (text/event-stream):
 * data: {"token": "Hello"}
 * data: {"token": " world"}
 * data: {"token": "!"}
 * data: [DONE]
 *
 * Output (application/json):
 * {
 *   "tokens": ["Hello", " world", "!"],
 *   "fullText": "Hello world!",
 *   "eventCount": 3
 * }
 */
%dw 2.0
input payload text/event-stream
output application/json

var events = payload
    filter (event) -> event.data != "[DONE]"
    map (event) -> read(event.data, "application/json")
---
{
    tokens: events map $.token,
    fullText: events reduce (event, acc = "") -> acc ++ event.token,
    eventCount: sizeOf(events)
}

// Alternative 1 — write SSE output (for producing event streams):
// %dw 2.0
// output text/event-stream
// ---
// payload.messages map (msg) -> {data: write(msg, "application/json")}

// Alternative 2 — with event type and ID fields:
// payload filter (e) -> e."type" == "message" map (e) -> {
//     id: e.id default "",
//     content: read(e.data, "application/json")
// }

// Alternative 3 — deferred streaming output for large payloads:
// %dw 2.0
// output text/event-stream deferred=true
// ---
// payload map (item) -> {data: write(item, "application/json")}
