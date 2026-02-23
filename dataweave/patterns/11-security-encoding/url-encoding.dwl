/**
 * Pattern: URL Encode/Decode
 * Category: Security & Encoding
 * Difficulty: Beginner
 *
 * Description: Encode and decode URL components. Essential for building
 * query strings, handling special characters in API calls, and parsing
 * form-urlencoded data.
 *
 * Input (application/json):
 * {
 *   "searchTerm": "MuleSoft & DataWeave 2.0",
 *   "redirectUrl": "https://example.com/callback?status=ok",
 *   "encodedParam": "MuleSoft+%26+DataWeave+2.0",
 *   "params": {
 *     "name": "John Doe",
 *     "city": "San José",
 *     "query": "price > 100"
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "encodedSearch": "MuleSoft%20%26%20DataWeave%202.0",
 *   "encodedRedirect": "https%3A%2F%2Fexample.com%2Fcallback%3Fstatus%3Dok",
 *   "decodedParam": "MuleSoft & DataWeave 2.0",
 *   "queryString": "name=John%20Doe&city=San%20Jos%C3%A9&query=price%20%3E%20100",
 *   "fullUrl": "https://api.example.com/search?name=John%20Doe&city=San%20Jos%C3%A9&query=price%20%3E%20100"
 * }
 */
%dw 2.0
import java!java::net::URLEncoder
import java!java::net::URLDecoder
output application/json

fun urlEncode(s: String): String =
    URLEncoder::encode(s, "UTF-8")

fun urlDecode(s: String): String =
    URLDecoder::decode(s, "UTF-8")

fun toQueryString(params: Object): String =
    params pluck (value, key) ->
        "$(urlEncode(key as String))=$(urlEncode(value as String))"
    joinBy "&"
---
{
    encodedSearch: urlEncode(payload.searchTerm),
    encodedRedirect: urlEncode(payload.redirectUrl),
    decodedParam: urlDecode(payload.encodedParam),
    queryString: toQueryString(payload.params),
    fullUrl: "https://api.example.com/search?$(toQueryString(payload.params))"
}
