/**
 * Pattern: CDATA Handling
 * Category: XML Handling
 * Difficulty: Intermediate
 *
 * Description: Read and write CDATA sections in XML. CDATA sections contain
 * text that should not be parsed as XML markup — common for embedding HTML
 * content, SQL queries, JSON strings, or any text with special characters
 * inside XML documents.
 *
 * Input (application/xml):
 * <Notification>
 *   <TemplateId>EMAIL-001</TemplateId>
 *   <Subject>Order Confirmation</Subject>
 *   <HtmlBody><![CDATA[<html><body><h1>Thank you!</h1><p>Your order <b>ORD-2026-1587</b> has been confirmed.</p></body></html>]]></HtmlBody>
 *   <SqlQuery><![CDATA[SELECT * FROM orders WHERE status = 'pending' AND amount > 100.00]]></SqlQuery>
 * </Notification>
 *
 * Output (application/json):
 * {
 *   "templateId": "EMAIL-001",
 *   "subject": "Order Confirmation",
 *   "htmlBody": "<html><body><h1>Thank you!</h1><p>Your order <b>ORD-2026-1587</b> has been confirmed.</p></body></html>",
 *   "sqlQuery": "SELECT * FROM orders WHERE status = 'pending' AND amount > 100.00"
 * }
 */
%dw 2.0
output application/json
---
{
    templateId: payload.Notification.TemplateId,
    subject: payload.Notification.Subject,
    htmlBody: payload.Notification.HtmlBody as String,
    sqlQuery: payload.Notification.SqlQuery as String
}

// Alternative 1 — write CDATA in XML output:
// %dw 2.0
// output application/xml
// ---
// {
//     Notification: {
//         Subject: "Order Confirmation",
//         HtmlBody: "<html><body><h1>Hello</h1></body></html>" as CData,
//         SqlQuery: "SELECT * FROM orders WHERE id = 'ORD-001'" as CData
//     }
// }

// Alternative 2 — conditionally wrap as CDATA (if contains special chars):
// var content = payload.body
// ---
// if (content contains "<" or content contains "&")
//     content as CData
// else content

// Alternative 3 — preserve CDATA when transforming XML to XML:
// %dw 2.0
// output application/xml
// ---
// payload.Notification mapObject (value, key) ->
//     if (value is CData) {(key): value}
//     else {(key): value}
