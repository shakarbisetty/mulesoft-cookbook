/**
 * Pattern: JSON to XML Conversion
 * Category: XML Handling
 * Difficulty: Intermediate
 *
 * Description: Convert a JSON payload to well-formed XML with elements and
 * attributes. Required when calling SOAP services, generating B2B documents,
 * or feeding data into legacy systems that only accept XML.
 *
 * Input (application/json):
 * {
 *   "order": {
 *     "orderId": "ORD-2026-1587",
 *     "orderDate": "2026-02-15",
 *     "customer": {
 *       "name": "Acme Corporation",
 *       "accountId": "ACCT-5001"
 *     },
 *     "items": [
 *       {"sku": "SKU-100", "description": "Mechanical Keyboard", "quantity": 5, "unitPrice": 149.99},
 *       {"sku": "SKU-400", "description": "Wireless Mouse", "quantity": 10, "unitPrice": 29.99}
 *     ]
 *   }
 * }
 *
 * Output (application/xml):
 * <?xml version='1.0' encoding='UTF-8'?>
 * <PurchaseOrder orderId="ORD-2026-1587" orderDate="2026-02-15">
 *   <Customer name="Acme Corporation" accountId="ACCT-5001"/>
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
 */
%dw 2.0
output application/xml
var order = payload.order
---
{
    PurchaseOrder @(orderId: order.orderId, orderDate: order.orderDate): {
        Customer @(name: order.customer.name, accountId: order.customer.accountId): null,
        Items: {(
            order.items map (item) -> {
                Item @(sku: item.sku, quantity: item.quantity): {
                    Description: item.description,
                    UnitPrice: item.unitPrice
                }
            }
        )}
    }
}

// Alternative 1 — simple JSON to XML (auto-mapped, elements only):
// %dw 2.0
// output application/xml
// ---
// {root: payload}

// Alternative 2 — set XML attributes with @():
// Element @(attr1: "value1", attr2: "value2"): "content"

// Alternative 3 — self-closing element (null content):
// Customer @(name: "Acme"): null
// Output: <Customer name="Acme"/>

// Alternative 4 — XML declaration and encoding:
// output application/xml encoding="UTF-8", indent=true
