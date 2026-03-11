/**
 * Pattern: CDATA Handling
 * Category: XML Handling
 * Difficulty: Intermediate
 * Description: Read and write CDATA sections in XML. CDATA sections contain
 * text that should not be parsed as XML markup — common for embedding HTML
 * content, SQL queries, JSON strings, or any text with special characters
 * inside XML documents.
 *
 * Input (application/xml):
 * <?xml version="1.0" encoding="UTF-8"?>
 * <Notification>
 *   <TemplateId>TPL-042</TemplateId>
 *   <Subject>Order Confirmation</Subject>
 *   <HtmlBody><![CDATA[<h1>Thank you</h1>
 *     <p>Order #5012 confirmed.</p>]]></HtmlBody>
 *   <SqlQuery><![CDATA[SELECT * FROM orders
 *     WHERE status = 'active']]></SqlQuery>
 * </Notification>
 *
 * Output (application/json):
 * {
 * "templateId": "EMAIL-001",
 * "subject": "Order Confirmation",
 * "htmlBody": "<html><body><h1>Thank you!</h1><p>Your order <b>ORD-2026-1587</b> has been confirmed.</p></body></html>",
 * "sqlQuery": "SELECT * FROM orders WHERE status = 'pending' AND amount > 100.00"
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
