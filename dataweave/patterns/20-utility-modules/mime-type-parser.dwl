/**
 * Pattern: MIME Type Parsing and Content Negotiation
 * Category: Utility Modules
 * Difficulty: Intermediate
 * Description: Parse and manipulate Content-Type headers using the dw::module::Mime
 * module (DW 2.7). Extract charset, boundary, and media type components for
 * API routing, content negotiation, and multipart processing.
 *
 * Input (application/json):
 * {
 *   "contentType": "multipart/form-data; boundary=----WebKit7MA; charset=utf-8",
 *   "accept": "application/json, text/xml;q=0.9, text/plain;q=0.5",
 *   "responseFormat": "application/json"
 * }
 *
 * Output (application/json):
 * {
 * "parsed": {
 * "mediaType": "multipart/form-data",
 * "type": "multipart",
 * "subType": "form-data",
 * "charset": "utf-8",
 * "boundary": "----WebKitFormBoundary7MA",
 * "isMultipart": true
 * },
 * "negotiated": "application/json",
 * "responseContentType": "application/json; charset=utf-8"
 * }
 */
%dw 2.0
import fromString from dw::module::Mime
output application/json
var parsed = fromString(payload.contentType)
var acceptList = (payload.accept splitBy ",") map trim($)
---
{
  mediaType: "$(parsed."type")/$(parsed.subType)",
  charset: parsed.parameters.charset default "unknown",
  isMultipart: parsed."type" == "multipart",
  topAccept: acceptList[0],
  responseType: payload.responseFormat
}
