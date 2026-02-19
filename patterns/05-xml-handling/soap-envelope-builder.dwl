/**
 * Pattern: SOAP Envelope Builder
 * Category: XML Handling
 * Difficulty: Advanced
 *
 * Description: Build a complete SOAP 1.1 or 1.2 request envelope from
 * JSON data. Includes headers (authentication, addressing), body with
 * namespaced elements, and proper attribute handling.
 *
 * Input (application/json):
 * {
 *   "operation": "CreateOrder",
 *   "namespace": "http://example.com/orders",
 *   "soapVersion": "1.1",
 *   "credentials": { "username": "apiUser", "password": "apiPass" },
 *   "body": {
 *     "orderId": "ORD-001",
 *     "customer": "Acme Corp",
 *     "items": [
 *       { "sku": "PROD-A", "qty": 5, "price": 29.99 },
 *       { "sku": "PROD-B", "qty": 2, "price": 49.99 }
 *     ]
 *   }
 * }
 *
 * Output (application/xml):
 * <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
 *                xmlns:ord="http://example.com/orders">
 *   <soap:Header>
 *     <wsse:Security xmlns:wsse="...">
 *       <wsse:UsernameToken>
 *         <wsse:Username>apiUser</wsse:Username>
 *         <wsse:Password>apiPass</wsse:Password>
 *       </wsse:UsernameToken>
 *     </wsse:Security>
 *   </soap:Header>
 *   <soap:Body>
 *     <ord:CreateOrder>
 *       <ord:OrderId>ORD-001</ord:OrderId>
 *       ...
 *     </ord:CreateOrder>
 *   </soap:Body>
 * </soap:Envelope>
 */
%dw 2.0
output application/xml writeDeclaration=true, indent=true

ns soap http://schemas.xmlsoap.org/soap/envelope/
ns wsse http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd
ns ord http://example.com/orders
---
{
    soap#Envelope: {
        soap#Header: {
            wsse#Security: {
                wsse#UsernameToken: {
                    wsse#Username: payload.credentials.username,
                    wsse#Password: payload.credentials.password
                }
            }
        },
        soap#Body: {
            ord#CreateOrder: {
                ord#OrderId: payload.body.orderId,
                ord#Customer: payload.body.customer,
                (payload.body.items map (item) -> {
                    ord#Item: {
                        ord#SKU: item.sku,
                        ord#Quantity: item.qty,
                        ord#UnitPrice: item.price
                    }
                })
            }
        }
    }
}

// Alternative — SOAP 1.2 (different namespace):
// ns soap http://www.w3.org/2003/05/soap-envelope
// The rest of the structure is the same
