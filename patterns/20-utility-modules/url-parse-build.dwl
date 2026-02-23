/**
 * Pattern: URL Parsing and Component Extraction
 * Category: Utility Modules
 * Difficulty: Beginner
 *
 * Description: Use dw::core::URL to decompose URLs into components and
 * build URLs from parts. Essential for dynamic API endpoint construction,
 * query parameter manipulation, redirect URL validation, and OAuth
 * callback handling.
 *
 * Input (application/json):
 * {
 *   "url": "https://api.example.com:8443/v2/orders?status=active&limit=50&offset=100#section2",
 *   "newParams": {"page": "3", "sort": "date_desc"}
 * }
 *
 * Output (application/json):
 * {
 *   "parsed": {
 *     "protocol": "https",
 *     "host": "api.example.com",
 *     "port": 8443,
 *     "path": "/v2/orders",
 *     "queryParams": {"status": "active", "limit": "50", "offset": "100"},
 *     "fragment": "section2"
 *   },
 *   "rebuilt": "https://api.example.com:8443/v2/orders?page=3&sort=date_desc",
 *   "baseUrl": "https://api.example.com:8443/v2/orders"
 * }
 */
%dw 2.0
import parseURI, encodeURIComponent from dw::core::URL
output application/json

var parsed = parseURI(payload.url)

// Build new query string from replacement params
var newQuery = payload.newParams pluck (v, k) ->
    "$(encodeURIComponent(k as String))=$(encodeURIComponent(v))"

var baseUrl = "$(parsed.scheme)://$(parsed.host)"
    ++ (if (parsed.port != -1) ":$(parsed.port)" else "")
    ++ parsed.path
---
{
    parsed: {
        protocol: parsed.scheme,
        host: parsed.host,
        port: if (parsed.port != -1) parsed.port else null,
        path: parsed.path,
        queryParams: if (parsed.query != null)
            (parsed.query splitBy "&") reduce (pair, acc = {}) -> do {
                var kv = pair splitBy "="
                ---
                acc ++ {(kv[0]): kv[1] default ""}
            }
            else {},
        fragment: parsed.fragment
    },
    rebuilt: baseUrl ++ "?" ++ (newQuery joinBy "&"),
    baseUrl: baseUrl
}

// Alternative 1 — encode path segments safely:
// var safePath = "/users/$(encodeURIComponent(userId))/orders"

// Alternative 2 — validate redirect URL (same-origin check):
// var redirect = parseURI(payload.redirectUrl)
// var allowed = redirect.host == "example.com" and redirect.scheme == "https"

// Alternative 3 — merge existing + new query params:
// var merged = existingParams ++ payload.newParams
// var queryString = merged pluck (v,k) -> "$(k)=$(encodeURIComponent(v))" joinBy "&"
