/**
 * Pattern: XML to JSON Conversion
 * Category: XML Handling
 * Difficulty: Intermediate
 *
 * Description: Convert an XML payload to a clean JSON structure. One of the
 * most common integration transformations — SOAP services, legacy systems,
 * and B2B integrations produce XML that modern REST APIs and frontends
 * consume as JSON. Handles elements, attributes, and nested structures.
 *
 * Input (application/xml):
 * <PurchaseOrder orderDate="2026-02-15" status="confirmed">
 *   <Customer>
 *     <Name>Acme Corporation</Name>
 *     <AccountId>ACCT-5001</AccountId>
 *     <Contact email="procurement@acme.com" phone="+1-555-0100"/>
 *   </Customer>
 *   <Items>
 *     <Item sku="SKU-100" quantity="5">
 *       <Description>Mechanical Keyboard</Description>
 *       <UnitPrice>149.99</UnitPrice>
 *     </Item>
 *     <Item sku="SKU-400" quantity="10">
 *       <Description>Wireless Mouse</Description>
 *       <UnitPrice>29.99</UnitPrice>
 *     </Item>
 *   </Items>
 * </PurchaseOrder>
 *
 * Output (application/json):
 * {
 *   "orderDate": "2026-02-15",
 *   "status": "confirmed",
 *   "customer": {
 *     "name": "Acme Corporation",
 *     "accountId": "ACCT-5001",
 *     "email": "procurement@acme.com",
 *     "phone": "+1-555-0100"
 *   },
 *   "items": [
 *     {"sku": "SKU-100", "description": "Mechanical Keyboard", "quantity": 5, "unitPrice": 149.99},
 *     {"sku": "SKU-400", "description": "Wireless Mouse", "quantity": 10, "unitPrice": 29.99}
 *   ]
 * }
 */
%dw 2.0
output application/json
var po = payload.PurchaseOrder
---
{
    orderDate: po.@orderDate,
    status: po.@status,
    customer: {
        name: po.Customer.Name,
        accountId: po.Customer.AccountId,
        email: po.Customer.Contact.@email,
        phone: po.Customer.Contact.@phone
    },
    items: po.Items.*Item map (item) -> {
        sku: item.@sku,
        description: item.Description,
        quantity: item.@quantity as Number,
        unitPrice: item.UnitPrice as Number
    }
}

// Alternative 1 — quick and dirty (let DW auto-convert):
// %dw 2.0
// output application/json
// ---
// payload
// Note: This preserves XML structure including @attributes and namespaces as-is

// Alternative 2 — handle repeating elements that may be single:
// (po.Items.*Item default [po.Items.Item]) map (item) -> { ... }

// Alternative 3 — access attributes with .@ shorthand:
// po.@orderDate         // single attribute
// po.Customer.Contact.@ // all attributes as object
