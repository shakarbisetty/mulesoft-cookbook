/**
 * Pattern: SOAP to REST
 * Category: Real-World Mappings
 * Difficulty: Intermediate
 *
 * Description: Transform a SOAP XML envelope response into a clean REST JSON
 * response. A core pattern in API-led connectivity — legacy SOAP services are
 * wrapped by MuleSoft Experience/Process APIs that expose modern REST/JSON
 * interfaces to consumers.
 *
 * Input (application/xml):
 * <soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/"
 *                xmlns:cust="http://legacy.acme.com/customer/v1">
 *   <soap:Header>
 *     <cust:ResponseHeader>
 *       <cust:TransactionId>TXN-20260215-001</cust:TransactionId>
 *       <cust:Timestamp>2026-02-15T14:30:00Z</cust:Timestamp>
 *     </cust:ResponseHeader>
 *   </soap:Header>
 *   <soap:Body>
 *     <cust:GetCustomerResponse>
 *       <cust:Customer status="active" tier="gold">
 *         <cust:CustomerId>C-100</cust:CustomerId>
 *         <cust:FirstName>Alice</cust:FirstName>
 *         <cust:LastName>Chen</cust:LastName>
 *         <cust:Email>alice@acme.com</cust:Email>
 *         <cust:Phone>+1-555-0142</cust:Phone>
 *         <cust:Addresses>
 *           <cust:Address type="billing">
 *             <cust:Street>123 Main St</cust:Street>
 *             <cust:City>San Francisco</cust:City>
 *             <cust:State>CA</cust:State>
 *             <cust:PostalCode>94102</cust:PostalCode>
 *           </cust:Address>
 *           <cust:Address type="shipping">
 *             <cust:Street>456 Oak Ave</cust:Street>
 *             <cust:City>San Francisco</cust:City>
 *             <cust:State>CA</cust:State>
 *             <cust:PostalCode>94108</cust:PostalCode>
 *           </cust:Address>
 *         </cust:Addresses>
 *       </cust:Customer>
 *     </cust:GetCustomerResponse>
 *   </soap:Body>
 * </soap:Envelope>
 *
 * Output (application/json):
 * {
 *   "customerId": "C-100",
 *   "firstName": "Alice",
 *   "lastName": "Chen",
 *   "email": "alice@acme.com",
 *   "phone": "+1-555-0142",
 *   "status": "active",
 *   "tier": "gold",
 *   "addresses": [
 *     {"type": "billing", "street": "123 Main St", "city": "San Francisco", "state": "CA", "postalCode": "94102"},
 *     {"type": "shipping", "street": "456 Oak Ave", "city": "San Francisco", "state": "CA", "postalCode": "94108"}
 *   ],
 *   "metadata": {
 *     "transactionId": "TXN-20260215-001",
 *     "timestamp": "2026-02-15T14:30:00Z"
 *   }
 * }
 */
%dw 2.0
output application/json
ns soap http://schemas.xmlsoap.org/soap/envelope/
ns cust http://legacy.acme.com/customer/v1
var header = payload.soap#Envelope.soap#Header.cust#ResponseHeader
var customer = payload.soap#Envelope.soap#Body.cust#GetCustomerResponse.cust#Customer
---
{
    customerId: customer.cust#CustomerId,
    firstName: customer.cust#FirstName,
    lastName: customer.cust#LastName,
    email: customer.cust#Email,
    phone: customer.cust#Phone,
    status: customer.@status,
    tier: customer.@tier,
    addresses: customer.cust#Addresses.*cust#Address map (addr) -> {
        "type": addr.@"type",
        street: addr.cust#Street,
        city: addr.cust#City,
        state: addr.cust#State,
        postalCode: addr.cust#PostalCode
    },
    metadata: {
        transactionId: header.cust#TransactionId,
        timestamp: header.cust#Timestamp
    }
}

// Alternative 1 — handle SOAP faults:
// var body = payload.soap#Envelope.soap#Body
// ---
// if (body.soap#Fault != null) {
//     error: true,
//     faultCode: body.soap#Fault.faultcode,
//     faultString: body.soap#Fault.faultstring
// }
// else { ... normal mapping ... }

// Alternative 2 — strip namespaces first for cleaner access:
// (see namespace-handling.dwl for the stripNs function)
