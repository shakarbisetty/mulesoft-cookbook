/**
 * Pattern: Metadata Annotations with the <~ Operator
 * Category: Advanced Patterns
 * Difficulty: Intermediate
 *
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
 *   <customer class="Person" source="CRM">
 *     <name>Alice Chen</name>
 *     <email>alice@example.com</email>
 *     <notes><![CDATA[Preferred customer since 2020 <VIP>]]></notes>
 *   </customer>
 * </order>
 */
%dw 2.0
output application/xml

---
{
    order @(id: payload.orderId): {
        customer @(class: "Person", source: "CRM"): {
            name: payload.customer.name,
            email: payload.customer.email,
            // Use <~ to set CDATA metadata on a string value
            notes: payload.customer.notes <~ {cdata: true}
        }
    }
}

// Alternative 1 — metadata on objects (class tagging):
// var tagged = {name: "Alice"} <~ {class: "Customer", version: 2}
// tagged.^class  // returns "Customer"

// Alternative 2 — conditional metadata:
// var value = payload.amount
// var annotated = if (value > 1000)
//     value <~ {flagged: true, reason: "high_value"}
//     else value <~ {flagged: false}

// Alternative 3 — reading metadata back:
// var data = payload.customer <~ {source: "API", timestamp: now()}
// var meta = data.^
// meta.source  // "API"
// meta.timestamp  // the timestamp value
