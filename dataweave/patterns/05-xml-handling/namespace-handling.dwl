/**
 * Pattern: Namespace Handling
 * Category: XML Handling
 * Difficulty: Advanced
 * Description: Work with XML namespaces — declare, read, transform, and strip
 * them. SOAP services, OAGIS, HL7, and enterprise XML schemas rely heavily
 * on namespaces. Understanding how DataWeave handles ns prefixes is essential
 * for B2B and enterprise integrations.
 *
 * Input (application/xml):
 * <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
 *                xmlns:ord="http://acme.com/orders/v2">
 *   <soap:Body>
 *     <ord:GetOrderResponse>
 *       <ord:Order>
 *         <ord:OrderId>ORD-2026-1587</ord:OrderId>
 *         <ord:Customer>Acme Corporation</ord:Customer>
 *         <ord:Total currency="USD">1049.85</ord:Total>
 *       </ord:Order>
 *     </ord:GetOrderResponse>
 *   </soap:Body>
 * </soap:Envelope>
 *
 * Output (application/json):
 * {
 * "orderId": "ORD-2026-1587",
 * "customer": "Acme Corporation",
 * "total": 1049.85,
 * "currency": "USD"
 * }
 */
%dw 2.0
output application/json
ns ord http://acme.com/orders/v2
var order = payload.soap#Envelope.soap#Body.ord#GetOrderResponse.ord#Order
---
{
    orderId: order.ord#OrderId,
    customer: order.ord#Customer,
    total: order.ord#Total as Number,
    currency: order.ord#Total.@currency
}
