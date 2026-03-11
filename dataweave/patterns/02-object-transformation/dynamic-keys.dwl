/**
 * Pattern: Dynamic Keys
 * Category: Object Transformation
 * Difficulty: Advanced
 * Description: Build objects with key names determined at runtime. Use the
 * (expression): value syntax to create keys from variables, payload fields,
 * or computed strings. Essential for pivoting data, building lookup maps, and
 * creating flexible schemas that adapt to input data.
 *
 * Input (application/json):
 * {
 *   "settings": [
 *     {
 *       "key": "theme",
 *       "value": "dark"
 *     },
 *     {
 *       "key": "language",
 *       "value": "en-US"
 *     },
 *     {
 *       "key": "maxRetries",
 *       "value": "3"
 *     }
 *   ]
 * }
 *
 * Output (application/json):
 * {
 * "theme": "dark",
 * "language": "en-US",
 * "notifications.email": "true",
 * "notifications.sms": "false",
 * "maxRetries": "3"
 * }
 */
%dw 2.0
output application/json
---
{(
  payload.settings map (setting) -> ({
    (setting.key): setting.value
  })
)}
