/**
 * Pattern: Dynamic Keys
 * Category: Object Transformation
 * Difficulty: Advanced
 *
 * Description: Build objects with key names determined at runtime. Use the
 * (expression): value syntax to create keys from variables, payload fields,
 * or computed strings. Essential for pivoting data, building lookup maps, and
 * creating flexible schemas that adapt to input data.
 *
 * Input (application/json):
 * {
 *   "settings": [
 *     {"key": "theme", "value": "dark"},
 *     {"key": "language", "value": "en-US"},
 *     {"key": "notifications.email", "value": "true"},
 *     {"key": "notifications.sms", "value": "false"},
 *     {"key": "maxRetries", "value": "3"}
 *   ]
 * }
 *
 * Output (application/json):
 * {
 *   "theme": "dark",
 *   "language": "en-US",
 *   "notifications.email": "true",
 *   "notifications.sms": "false",
 *   "maxRetries": "3"
 * }
 */
%dw 2.0
output application/json
---
{(
    payload.settings map (setting) -> {
        (setting.key): setting.value
    }
)}

// Alternative 1 — using reduce to build the object:
// payload.settings reduce (setting, acc = {}) ->
//     acc ++ {(setting.key): setting.value}

// Alternative 2 — dynamic keys with computed names:
// var prefix = "config"
// ---
// {(
//     payload.settings map (setting) -> {
//         (prefix ++ "." ++ setting.key): setting.value
//     }
// )}

// Alternative 3 — build a lookup map from an array (indexBy equivalent):
// Input: [{id: "US", name: "United States"}, {id: "CA", name: "Canada"}]
// {(payload map (item) -> {(item.id): item.name})}
// Output: {"US": "United States", "CA": "Canada"}

// Alternative 4 — conditional dynamic keys:
// {
//     name: payload.name,
//     (if (payload.email != null) "email" else "noEmail"): payload.email default "N/A"
// }
