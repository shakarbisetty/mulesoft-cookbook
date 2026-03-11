/**
 * Pattern: Attribute Extraction
 * Category: XML Handling
 * Difficulty: Intermediate
 * Description: Extract XML attributes from elements using the .@ selector.
 * XML attributes carry metadata (IDs, types, currencies, dates) on elements.
 * Understanding attribute access is critical for SOAP, HL7, EDI-XML, and
 * any schema-heavy XML integration.
 *
 * Input (application/xml):
 * <?xml version="1.0" encoding="UTF-8"?>
 * <Catalog version="2.1" lastUpdated="2025-09-10">
 *   <Product sku="SKU-1001" category="Electronics" featured="true">
 *     <Name lang="en">Wireless Mouse</Name>
 *     <Price currency="USD">29.99</Price>
 *     <Dimensions unit="cm" length="10" width="6" height="4"/>
 *   </Product>
 *   <Product sku="SKU-1002" category="Home" featured="false">
 *     <Name lang="en">Desk Lamp</Name>
 *     <Price currency="USD">45.00</Price>
 *     <Dimensions unit="cm" length="35" width="15" height="50"/>
 *   </Product>
 * </Catalog>
 *
 * Output (application/json):
 * {
 * "catalogVersion": "3.1",
 * "lastUpdated": "2026-02-15",
 * "products": [
 * {
 * "sku": "SKU-100",
 * "category": "electronics",
 * "featured": true,
 * "name": "Mechanical Keyboard",
 * "language": "en",
 * "price": 149.99,
 * "currency": "USD",
 * "dimensions": {"unit": "cm", "length": 45, "width": 15, "height": 4}
 * },
 * {
 * "sku": "SKU-400",
 * "category": "electronics",
 * "featured": false,
 * "name": "Wireless Mouse",
 * "language": "en",
 * "price": 29.99,
 * "currency": "USD",
 * "dimensions": {"unit": "cm", "length": 12, "width": 7, "height": 4}
 * }
 * ]
 * }
 */
%dw 2.0
output application/json
---
payload.Catalog.*Product map (product) -> ({sku: product.@sku, category: product.@category, featured: product.@featured as Boolean, name: product.Name, nameLang: product.Name.@lang, price: product.Price as Number, currency: product.Price.@currency, length: product.Dimensions.@length as Number, width: product.Dimensions.@width as Number, height: product.Dimensions.@height as Number, unit: product.Dimensions.@unit})
