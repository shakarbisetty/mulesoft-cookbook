/**
 * Pattern: Default Values
 * Category: Error Handling
 * Difficulty: Beginner
 * Description: Provide fallback values for null or missing fields using the
 * `default` operator. The first line of defense against null pointer errors
 * in DataWeave. Use whenever a field might be missing, null, or empty in
 * the source payload.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "Alice Chen",
 *     "email": null,
 *     "phone": "+1-555-0142",
 *     "preferences": {
 *       "language": null,
 *       "currency": "EUR"
 *     }
 *   },
 *   "shippingAddress": null,
 *   "notes": ""
 * }
 *
 * Output (application/json):
 * {
 * "name": "Alice Chen",
 * "email": "noreply@example.com",
 * "phone": "+1-555-0142",
 * "language": "en",
 * "currency": "EUR",
 * "shippingAddress": "No address provided",
 * "notes": "No notes",
 * "loyaltyTier": "Standard",
 * "tags": []
 * }
 */
%dw 2.0
output application/json
---
{
  name: payload.customer.name default "Unknown",
  email: payload.customer.email default "noreply@example.com",
  phone: payload.customer.phone default "N/A",
  language: payload.customer.preferences.language default "en",
  currency: payload.customer.preferences.currency default "USD",
  shippingAddress: payload.shippingAddress default "No address on file",
  notes: if (payload.notes == "") "No notes" else payload.notes
}
