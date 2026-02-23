/**
 * Pattern: Namespace Handling
 * Category: XML Handling
 * Difficulty: Advanced
 *
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
 *   "orderId": "ORD-2026-1587",
 *   "customer": "Acme Corporation",
 *   "total": 1049.85,
 *   "currency": "USD"
 * }
 */
%dw 2.0
output application/json
ns soap http://schemas.xmlsoap.org/soap/envelope/
ns ord http://acme.com/orders/v2
var order = payload.soap#Envelope.soap#Body.ord#GetOrderResponse.ord#Order
---
{
    orderId: order.ord#OrderId,
    customer: order.ord#Customer,
    total: order.ord#Total as Number,
    currency: order.ord#Total.@currency
}

// Alternative 1 — strip all namespaces first, then access by local name:
// %dw 2.0
// output application/json
// import * from dw::core::Objects
// fun stripNs(data: Any): Any = data match {
//     case obj is Object -> obj mapObject (v, k) ->
//         {((k as String splitBy "#")[-1]): stripNs(v)}
//     case arr is Array -> arr map stripNs($)
//     else -> data
// }
// ---
// stripNs(payload)

// Alternative 2 — write XML with namespaces:
// %dw 2.0
// output application/xml
// ns ord http://acme.com/orders/v2
// ---
// {ord#Order @(xmlns: "http://acme.com/orders/v2"): {
//     ord#OrderId: "ORD-2026-1587",
//     ord#Customer: "Acme Corporation"
// }}

// Alternative 3 — wildcard namespace access (any namespace):
// payload.*:Envelope.*:Body.*:GetOrderResponse.*:Order
