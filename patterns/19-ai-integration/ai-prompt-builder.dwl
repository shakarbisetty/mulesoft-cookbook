/**
 * Pattern: AI Prompt Builder for Inference Connector
 * Category: AI Integration
 * Difficulty: Intermediate
 *
 * Description: Build structured prompts from enterprise data for MuleSoft's
 * Inference Connector. Transforms raw business objects into well-formatted
 * LLM prompt payloads with system instructions, context injection, and
 * structured output requirements.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "Acme Corp",
 *     "tier": "Enterprise",
 *     "openTickets": 3,
 *     "lastInteraction": "2026-02-15"
 *   },
 *   "ticketHistory": [
 *     {"id": "TK-101", "subject": "API timeout on /orders", "status": "open", "priority": "high"},
 *     {"id": "TK-098", "subject": "OAuth token refresh failing", "status": "open", "priority": "medium"},
 *     {"id": "TK-095", "subject": "Batch job stuck at 80%", "status": "open", "priority": "low"}
 *   ],
 *   "model": "gpt-4o",
 *   "maxTokens": 500
 * }
 *
 * Output (application/json):
 * {
 *   "model": "gpt-4o",
 *   "max_tokens": 500,
 *   "messages": [
 *     {"role": "system", "content": "You are an enterprise support analyst..."},
 *     {"role": "user", "content": "Analyze the following tickets for Acme Corp (Enterprise tier)..."}
 *   ],
 *   "response_format": {"type": "json_object"}
 * }
 */
%dw 2.0
output application/json

var systemPrompt = "You are an enterprise support analyst. Analyze support tickets and provide: (1) a priority ranking, (2) root cause hypothesis for each, (3) recommended next action. Respond in JSON with keys: priorityRanking, analyses, summary."

var ticketContext = payload.ticketHistory map (t) ->
    "- [$(t.priority upper)] $(t.id): $(t.subject) ($(t.status))"

var userPrompt = "Analyze the following tickets for $(payload.customer.name) ($(payload.customer.tier) tier, $(payload.customer.openTickets) open tickets, last interaction: $(payload.customer.lastInteraction)):\n\n$(ticketContext joinBy '\n')\n\nProvide your analysis in JSON format."
---
{
    model: payload.model,
    max_tokens: payload.maxTokens,
    messages: [
        {role: "system", content: systemPrompt},
        {role: "user", content: userPrompt}
    ],
    response_format: {"type": "json_object"}
}

// Alternative 1 — with few-shot examples:
// messages: [
//     {role: "system", content: systemPrompt},
//     {role: "user", content: "Example input: ..."},
//     {role: "assistant", content: "{\"priorityRanking\": [...]}"},
//     {role: "user", content: userPrompt}
// ]

// Alternative 2 — token budget estimation:
// var estimatedTokens = sizeOf(userPrompt) / 4  // rough char-to-token ratio
// var safeMaxTokens = if (estimatedTokens > 3000) 1000 else 500
