/**
 * Pattern: Attribute Extraction
 * Category: XML Handling
 * Difficulty: Intermediate
 *
 * Description: Extract XML attributes from elements using the .@ selector.
 * XML attributes carry metadata (IDs, types, currencies, dates) on elements.
 * Understanding attribute access is critical for SOAP, HL7, EDI-XML, and
 * any schema-heavy XML integration.
 *
 * Input (application/xml):
 * <Catalog lastUpdated="2026-02-15" version="3.1">
 *   <Product sku="SKU-100" category="electronics" featured="true">
 *     <Name lang="en">Mechanical Keyboard</Name>
 *     <Price currency="USD" taxIncluded="false">149.99</Price>
 *     <Dimensions unit="cm" length="45" width="15" height="4"/>
 *   </Product>
 *   <Product sku="SKU-400" category="electronics" featured="false">
 *     <Name lang="en">Wireless Mouse</Name>
 *     <Price currency="USD" taxIncluded="false">29.99</Price>
 *     <Dimensions unit="cm" length="12" width="7" height="4"/>
 *   </Product>
 * </Catalog>
 *
 * Output (application/json):
 * {
 *   "catalogVersion": "3.1",
 *   "lastUpdated": "2026-02-15",
 *   "products": [
 *     {
 *       "sku": "SKU-100",
 *       "category": "electronics",
 *       "featured": true,
 *       "name": "Mechanical Keyboard",
 *       "language": "en",
 *       "price": 149.99,
 *       "currency": "USD",
 *       "dimensions": {"unit": "cm", "length": 45, "width": 15, "height": 4}
 *     },
 *     {
 *       "sku": "SKU-400",
 *       "category": "electronics",
 *       "featured": false,
 *       "name": "Wireless Mouse",
 *       "language": "en",
 *       "price": 29.99,
 *       "currency": "USD",
 *       "dimensions": {"unit": "cm", "length": 12, "width": 7, "height": 4}
 *     }
 *   ]
 * }
 */
%dw 2.0
output application/json
---
{
    catalogVersion: payload.Catalog.@version,
    lastUpdated: payload.Catalog.@lastUpdated,
    products: payload.Catalog.*Product map (product) -> {
        sku: product.@sku,
        category: product.@category,
        featured: product.@featured as Boolean,
        name: product.Name as String,
        language: product.Name.@lang,
        price: product.Price as Number,
        currency: product.Price.@currency,
        dimensions: {
            unit: product.Dimensions.@unit,
            length: product.Dimensions.@length as Number,
            width: product.Dimensions.@width as Number,
            height: product.Dimensions.@height as Number
        }
    }
}

// Alternative 1 — get all attributes of an element as an object:
// payload.Catalog.Product.@
// Output: {sku: "SKU-100", category: "electronics", featured: "true"}

// Alternative 2 — set attributes when building XML:
// {Product @(sku: "SKU-100", category: "electronics"): {
//     Name @(lang: "en"): "Keyboard"
// }}

// Alternative 3 — filter by attribute value:
// payload.Catalog.*Product filter ($.@featured == "true")
