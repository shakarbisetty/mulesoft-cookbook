/**
 * Pattern: AI Prompt Builder for Inference Connector
 * Category: AI Integration
 * Difficulty: Intermediate
 * Description: Build structured prompts from enterprise data for MuleSoft's
 * Inference Connector. Transforms raw business objects into well-formatted
 * LLM prompt payloads with system instructions, context injection, and
 * structured output requirements.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "Acme Corp",
 *     "tier": "Enterprise"
 *   },
 *   "ticketHistory": [
 *     {
 *       "id": "TK-101",
 *       "subject": "API timeout",
 *       "status": "open",
 *       "priority": "high"
 *     },
 *     {
 *       "id": "TK-098",
 *       "subject": "OAuth refresh failing",
 *       "status": "open",
 *       "priority": "medium"
 *     },
 *     {
 *       "id": "TK-095",
 *       "subject": "Batch stuck at 80 pct",
 *       "status": "open",
 *       "priority": "low"
 *     }
 *   ],
 *   "model": "gpt-4o",
 *   "maxTokens": 500
 * }
 *
 * Output (application/json):
 * {
 * "model": "gpt-4o",
 * "max_tokens": 500,
 * "messages": [
 * {"role": "system", "content": "You are an enterprise support analyst..."},
 * {"role": "user", "content": "Analyze the following tickets for Acme Corp (Enterprise tier)..."}
 * ],
 * "response_format": {"type": "json_object"}
 * }
 */
%dw 2.0
output application/json
var systemPrompt = "You are an enterprise support analyst."
var lines = payload.ticketHistory map (t) -> "- [$(t.priority upper)] $(t.id): $(t.subject)"
var userPrompt = "Analyze tickets for $(payload.customer.name):\n" ++ (lines joinBy "\n")
---
{
  model: payload.model,
  max_tokens: payload.maxTokens,
  messages: [
    {role: "system", content: systemPrompt},
    {role: "user", content: userPrompt}
  ]
}
