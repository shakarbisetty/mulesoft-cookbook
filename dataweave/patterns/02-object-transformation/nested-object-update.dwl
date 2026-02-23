/**
 * Pattern: Nested Object Update
 * Category: Object Transformation
 * Difficulty: Advanced
 *
 * Description: Update a field deep inside a nested object without rebuilding the
 * entire structure. The update operator lets you target a specific path and
 * modify just that value — everything else stays intact. Critical for patching
 * API payloads, updating config structures, and modifying deeply nested
 * integration messages.
 *
 * Input (application/json):
 * {
 *   "orderId": "ORD-2026-1587",
 *   "customer": {
 *     "name": "Alice Chen",
 *     "address": {
 *       "street": "123 Main Street",
 *       "city": "San Francisco",
 *       "state": "CA",
 *       "zip": "94102",
 *       "country": "US"
 *     },
 *     "contacts": {
 *       "primary": {
 *         "email": "alice@oldcompany.com",
 *         "phone": "+1-555-0142"
 *       },
 *       "billing": {
 *         "email": "billing@oldcompany.com",
 *         "phone": "+1-555-0199"
 *       }
 *     }
 *   },
 *   "status": "processing"
 * }
 *
 * Output (application/json):
 * {
 *   "orderId": "ORD-2026-1587",
 *   "customer": {
 *     "name": "Alice Chen",
 *     "address": {
 *       "street": "456 Oak Avenue",
 *       "city": "San Francisco",
 *       "state": "CA",
 *       "zip": "94108",
 *       "country": "US"
 *     },
 *     "contacts": {
 *       "primary": {
 *         "email": "alice@newcompany.com",
 *         "phone": "+1-555-0142"
 *       },
 *       "billing": {
 *         "email": "billing@oldcompany.com",
 *         "phone": "+1-555-0199"
 *       }
 *     }
 *   },
 *   "status": "processing"
 * }
 */
%dw 2.0
output application/json
---
payload update {
    case address at .customer.address -> address ++ {
        street: "456 Oak Avenue",
        zip: "94108"
    }
    case email at .customer.contacts.primary.email -> "alice@newcompany.com"
}

// Alternative 1 — manual rebuild (verbose, but works in all DW versions):
// payload ++ {
//     customer: payload.customer ++ {
//         address: payload.customer.address ++ {
//             street: "456 Oak Avenue",
//             zip: "94108"
//         },
//         contacts: payload.customer.contacts ++ {
//             primary: payload.customer.contacts.primary ++ {
//                 email: "alice@newcompany.com"
//             }
//         }
//     }
// }

// Alternative 2 — update with transformation (e.g., uppercase a nested field):
// payload update {
//     case name at .customer.name -> upper(name)
// }

// Alternative 3 — update array elements within a nested structure:
// payload update {
//     case items at .order.lineItems -> items map (item) ->
//         if (item.sku == "SKU-100") item ++ {price: 139.99}
//         else item
// }
