/**
 * Pattern: JSON to XML Conversion
 * Category: XML Handling
 * Difficulty: Intermediate
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
 *       "name": "Acme Corp",
 *       "accountId": "ACCT-5001"
 *     },
 *     "items": [
 *       {
 *         "sku": "SKU-100",
 *         "desc": "Keyboard",
 *         "qty": 5,
 *         "price": 149.99
 *       },
 *       {
 *         "sku": "SKU-400",
 *         "desc": "Mouse",
 *         "qty": 10,
 *         "price": 29.99
 *       }
 *     ]
 *   }
 * }
 *
 * Output (application/xml):
 * <?xml version='1.0' encoding='UTF-8'?>
 * <PurchaseOrder orderId="ORD-2026-1587" orderDate="2026-02-15">
 * <Customer name="Acme Corporation" accountId="ACCT-5001"/>
 * <Items>
 * <Item sku="SKU-100" quantity="5">
 * <Description>Mechanical Keyboard</Description>
 * <UnitPrice>149.99</UnitPrice>
 * </Item>
 * <Item sku="SKU-400" quantity="10">
 * <Description>Wireless Mouse</Description>
 * <UnitPrice>29.99</UnitPrice>
 * </Item>
 * </Items>
 * </PurchaseOrder>
 */
%dw 2.0
output application/xml
---
{
  PurchaseOrder @(orderId: payload.order.orderId, orderDate: payload.order.orderDate): {
    Customer @(name: payload.order.customer.name, accountId: payload.order.customer.accountId): null,
    Items: { (payload.order.items map (item) -> ({
      Item @(sku: item.sku, quantity: item.qty): {
        Description: item.desc,
        UnitPrice: item.price
      })
    }) }
  }
}
