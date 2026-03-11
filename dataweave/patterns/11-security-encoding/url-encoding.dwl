/**
 * Pattern: URL Encode/Decode
 * Category: Security & Encoding
 * Difficulty: Beginner
 * Description: Encode and decode URL components. Essential for building
 * query strings, handling special characters in API calls, and parsing
 * form-urlencoded data.
 *
 * Input (application/json):
 * {
 *   "searchTerm": "MuleSoft & DataWeave",
 *   "params": {
 *     "name": "John Doe",
 *     "city": "New York",
 *     "lang": "en"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "encodedSearch": "MuleSoft%20%26%20DataWeave%202.0",
 * "encodedRedirect": "https%3A%2F%2Fexample.com%2Fcallback%3Fstatus%3Dok",
 * "decodedParam": "MuleSoft & DataWeave 2.0",
 * "queryString": "name=John%20Doe&city=San%20Jos%C3%A9&query=price%20%3E%20100",
 * "fullUrl": "https://api.example.com/search?name=John%20Doe&city=San%20Jos%C3%A9&query=price%20%3E%20100"
 * }
 */
%dw 2.0
import encodeURIComponent from dw::core::URL
output application/json
fun urlEncode(s: String): String = encodeURIComponent(s)
fun toQueryString(params: Object): String = do { var parts = params pluck (v, k) -> "$(urlEncode(k as String))=$(urlEncode(v as String))" --- parts joinBy "&" }
---
{encodedSearch: urlEncode(payload.searchTerm), queryString: toQueryString(payload.params), fullUrl: "https://api.example.com?" ++ toQueryString(payload.params)}
