/**
 * Pattern: Metadata Annotations with the <~ Operator
 * Category: Advanced Patterns
 * Difficulty: Intermediate
 * Description: Use the metadata assignment operator <~ (DW 2.5) to attach
 * metadata to values without type coercion. Simpler than the 'as' approach
 * for tagging data with class info, CDATA markers, XML attributes, and
 * custom annotations.
 *
 * Input (application/json):
 * {
 *   "customer": {
 *     "name": "Alice Chen",
 *     "email": "alice@example.com",
 *     "notes": "Preferred customer since 2020 <VIP>"
 *   },
 *   "orderId": "ORD-12345"
 * }
 *
 * Output (application/xml):
 * <?xml version="1.0" encoding="UTF-8"?>
 * <order id="ORD-12345">
 * <customer class="Person" source="CRM">
 * <name>Alice Chen</name>
 * <email>alice@example.com</email>
 * <notes><![CDATA[Preferred customer since 2020 <VIP>]]></notes>
 * </customer>
 * </order>
 */
%dw 2.0
output application/xml
---
order @(id: payload.orderId): {
    customer @(class: "Person", source: "CRM"): {
        name: payload.customer.name,
        email: payload.customer.email,
        notes: payload.customer.notes <~ {cdata: true}
    }
}
