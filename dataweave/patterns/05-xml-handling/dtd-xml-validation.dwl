/**
 * Pattern: XML DTD Declaration Handling
 * Category: XML Handling
 * Difficulty: Advanced
 * Description: Work with XML Document Type Declarations using the dw::xml::Dtd
 * module (DW 2.5). Parse DTD-declared entities, validate document structure,
 * and handle legacy enterprise XML systems that rely on DTD-based entity
 * definitions and validation.
 *
 * Input (application/xml):
 * <?xml version="1.0"?>
 * <invoice id="INV-001">
 *   <header>
 *     <vendor>Acme Corp</vendor>
 *     <date>2026-02-22</date>
 *     <currency>USD</currency>
 *   </header>
 *   <lineItems>
 *     <item sku="WDG-001" qty="10"><description>Widget A</description><unitPrice>19.99</unitPrice></item>
 *     <item sku="WDG-002" qty="5"><description>Widget B</description><unitPrice>49.95</unitPrice></item>
 *   </lineItems>
 * </invoice>
 *
 * Output (application/json):
 * {
 * "invoiceId": "INV-2026-001",
 * "vendor": "Acme Corp",
 * "date": "2026-02-22",
 * "currency": "USD",
 * "lineItems": [
 * {"sku": "WDG-001", "description": "Widget A", "quantity": 10, "unitPrice": 19.99, "lineTotal": 199.90},
 * {"sku": "WDG-002", "description": "Widget B", "quantity": 5, "unitPrice": 49.95, "lineTotal": 249.75}
 * ],
 * "total": 449.65
 * }
 */
%dw 2.0
output application/json
var header = payload.invoice.header
var items = payload.invoice.lineItems.*item
---
{
  invoiceId: payload.invoice.@id,
  vendor: header.vendor,
  date: header.date,
  lineItems: items map (item) -> do {
    var qty = item.@qty as Number
    var price = item.unitPrice as Number
    ---
    {sku: item.@sku, description: item.description, quantity: qty, unitPrice: price, lineTotal: qty * price}
  },
  total: items reduce (item, acc = 0) -> acc + ((item.@qty as Number) * (item.unitPrice as Number))
}
