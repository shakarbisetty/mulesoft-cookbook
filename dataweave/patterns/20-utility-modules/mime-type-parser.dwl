/**
 * Pattern: MIME Type Parsing and Content Negotiation
 * Category: Utility Modules
 * Difficulty: Intermediate
 *
 * Description: Parse and manipulate Content-Type headers using the dw::module::Mime
 * module (DW 2.7). Extract charset, boundary, and media type components for
 * API routing, content negotiation, and multipart processing.
 *
 * Input (application/json):
 * {
 *   "contentType": "multipart/form-data; boundary=----WebKitFormBoundary7MA; charset=utf-8",
 *   "accept": "application/json, text/xml;q=0.9, text/plain;q=0.5",
 *   "responseFormat": "application/json"
 * }
 *
 * Output (application/json):
 * {
 *   "parsed": {
 *     "mediaType": "multipart/form-data",
 *     "type": "multipart",
 *     "subType": "form-data",
 *     "charset": "utf-8",
 *     "boundary": "----WebKitFormBoundary7MA",
 *     "isMultipart": true
 *   },
 *   "negotiated": "application/json",
 *   "responseContentType": "application/json; charset=utf-8"
 * }
 */
%dw 2.0
import fromString, toString from dw::module::Mime
output application/json

var parsed = fromString(payload.contentType)

// Parse Accept header to find preferred format
var acceptTypes = (payload.accept splitBy ",")
    map (entry) -> trim(entry)
    map (entry) -> do {
        var parts = entry splitBy ";"
        ---
        {
            mediaType: trim(parts[0]),
            quality: if (sizeOf(parts) > 1)
                (parts[1] match /q=(\d+\.?\d*)/ then $.groups[1] as Number default 1.0)
                else 1.0
        }
    }
    orderBy -$.quality
---
{
    parsed: {
        mediaType: "$(parsed."type")/$(parsed.subType)",
        "type": parsed."type",
        subType: parsed.subType,
        charset: parsed.parameters.charset default "not specified",
        boundary: parsed.parameters.boundary default "not specified",
        isMultipart: parsed."type" == "multipart"
    },
    negotiated: acceptTypes[0].mediaType,
    responseContentType: toString({
        "type": (payload.responseFormat splitBy "/")[0],
        subType: (payload.responseFormat splitBy "/")[1],
        parameters: {charset: "utf-8"}
    })
}

// Alternative 1 — simple charset extraction:
// var ct = fromString(attributes.headers."Content-Type")
// var encoding = ct.parameters.charset default "UTF-8"

// Alternative 2 — detect JSON vs XML for routing:
// var isJson = fromString(attributes.headers."Content-Type").subType == "json"
// var isXml = fromString(attributes.headers."Content-Type").subType == "xml"
