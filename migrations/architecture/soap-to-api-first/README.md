## SOAP Services to API-First REST
> Migrate SOAP web services to API-first REST design with MuleSoft

### When to Use
- Legacy SOAP services need modernization
- Consumers need REST/JSON interfaces
- Building API-first strategy
- Reducing SOAP/XML overhead

### Configuration / Code

#### 1. Expose Existing SOAP as REST (Facade Pattern)

```xml
<!-- REST facade over existing SOAP service -->
<flow name="rest-to-soap-facade">
    <http:listener config-ref="HTTP_Listener"
        path="/api/v1/customers/{id}" method="GET" />

    <!-- Transform REST request to SOAP -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/xml
ns soap http://schemas.xmlsoap.org/soap/envelope/
ns cust http://example.com/customer
---
{
    soap#Envelope: {
        soap#Body: {
            cust#GetCustomer: {
                cust#CustomerId: attributes.uriParams.id
            }
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <!-- Call SOAP service -->
    <http:request config-ref="SOAP_Backend"
        method="POST" path="/CustomerService">
        <http:headers>#[{
            'Content-Type': 'text/xml',
            'SOAPAction': 'GetCustomer'
        }]</http:headers>
    </http:request>

    <!-- Transform SOAP response to JSON -->
    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
ns cust http://example.com/customer
var body = payload.Envelope.Body
---
{
    id: body.GetCustomerResponse.Customer.Id,
    name: body.GetCustomerResponse.Customer.Name,
    email: body.GetCustomerResponse.Customer.Email
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### 2. API-First Design (RAML)

```yaml
#%RAML 1.0
title: Customer API
version: v1
baseUri: https://api.example.com/v1

types:
  Customer:
    type: object
    properties:
      id: integer
      name: string
      email: string

/customers:
  get:
    queryParameters:
      page: { type: integer, default: 1 }
    responses:
      200:
        body:
          application/json:
            type: Customer[]
  /{id}:
    get:
      responses:
        200:
          body:
            application/json:
              type: Customer
        404:
          body:
            application/json:
              example: { "error": "Customer not found" }
```

#### 3. Web Service Consumer (WSDL-based)

```xml
<!-- Use Web Service Consumer for cleaner SOAP integration -->
<wsc:config name="SOAP_Config">
    <wsc:connection
        wsdlLocation="CustomerService.wsdl"
        service="CustomerService"
        port="CustomerPort"
        address="https://legacy.example.com/ws/CustomerService" />
</wsc:config>

<flow name="customer-system-api">
    <http:listener config-ref="HTTP" path="/customers/{id}" method="GET" />

    <wsc:consume config-ref="SOAP_Config" operation="GetCustomer">
        <wsc:message>
            <wsc:body><![CDATA[%dw 2.0
output application/xml
ns cust http://example.com/customer
--- { cust#GetCustomer: { cust#CustomerId: attributes.uriParams.id } }]]></wsc:body>
        </wsc:message>
    </wsc:consume>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
--- { id: payload.body.Customer.Id, name: payload.body.Customer.Name }]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### How It Works
1. API-first: design the REST API contract first (RAML/OAS)
2. System API wraps the SOAP backend with REST interface
3. DataWeave handles XML-to-JSON and JSON-to-XML transformation
4. Web Service Consumer connector simplifies SOAP calls

### Migration Checklist
- [ ] Inventory all SOAP services and their operations
- [ ] Design REST API contracts (RAML/OAS) for each
- [ ] Build System APIs as REST facades
- [ ] Implement XML/JSON transformations
- [ ] Migrate consumers to use REST endpoints
- [ ] Add API management (security, rate limiting)
- [ ] Monitor both SOAP and REST during transition
- [ ] Decommission SOAP endpoints when all consumers migrated

### Gotchas
- SOAP complex types may not map cleanly to JSON
- WS-Security, WS-ReliableMessaging have no direct REST equivalents
- SOAP WSDL operations may not map 1:1 to REST resources
- XML namespaces require careful DataWeave handling
- SOAP fault handling must be mapped to HTTP status codes

### Related
- [monolith-to-api-led](../monolith-to-api-led/) - API-led architecture
- [esb-to-api-led](../esb-to-api-led/) - ESB migration
- [raml-to-oas3](../../api-specs/raml-to-oas3/) - API spec formats
