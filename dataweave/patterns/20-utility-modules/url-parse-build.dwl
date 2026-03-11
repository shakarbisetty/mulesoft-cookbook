/**
 * Pattern: URL Parsing and Component Extraction
 * Category: Utility Modules
 * Difficulty: Beginner
 * Description: Use dw::core::URL to decompose URLs into components and
 * build URLs from parts. Essential for dynamic API endpoint construction,
 * query parameter manipulation, redirect URL validation, and OAuth
 * callback handling.
 *
 * Input (application/json):
 * {
 *   "url": "https://api.example.com:8443/v2/orders?status=active&limit=50",
 *   "newParams": {
 *     "page": "3",
 *     "sort": "date_desc"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "parsed": {
 * "protocol": "https",
 * "host": "api.example.com",
 * "port": 8443,
 * "path": "/v2/orders",
 * "queryParams": {"status": "active", "limit": "50", "offset": "100"},
 * "fragment": "section2"
 * },
 * "rebuilt": "https://api.example.com:8443/v2/orders?page=3&sort=date_desc",
 * "baseUrl": "https://api.example.com:8443/v2/orders"
 * }
 */
%dw 2.0
import parseURI, encodeURIComponent from dw::core::URL
output application/json
var parsed = parseURI(payload.url)
var queryParts = payload.newParams pluck (v, k) -> "$(encodeURIComponent(k as String))=$(encodeURIComponent(v))"
var newQuery = queryParts joinBy "&"
var baseUrl = (parsed.scheme default "https") ++ "://" ++ (parsed.host default "") ++ (if (parsed.port != null) (":" ++ (parsed.port as String)) else "") ++ (parsed.path default "")
---
({parsed: ({protocol: parsed.scheme, host: parsed.host, port: if (parsed.port != null) parsed.port else null, path: parsed.path}), rebuilt: baseUrl ++ "?" ++ newQuery, baseUrl: baseUrl})
