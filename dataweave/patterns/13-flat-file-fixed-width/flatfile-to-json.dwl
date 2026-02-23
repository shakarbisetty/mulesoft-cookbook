/**
 * Pattern: Flat File to JSON
 * Category: Flat File & Fixed-Width
 * Difficulty: Intermediate
 *
 * Description: Transform a legacy pipe-delimited or fixed-width flat file
 * into a modern JSON structure with proper types, nested objects, and
 * array grouping. Typical for mainframe-to-API modernization projects.
 *
 * Input (text/plain):
 * CUST-001|John Doe|john@example.com|123 Main St|Austin|TX|78701|GOLD|2020-01-15
 * CUST-001|John Doe|john@example.com|456 Oak Ave|Austin|TX|78702|GOLD|2020-01-15
 * CUST-002|Jane Smith|jane@example.com|789 Elm Blvd|New York|NY|10001|SILVER|2021-06-01
 * CUST-003|Bob Johnson|bob@example.com|321 Pine Dr|Chicago|IL|60601|BRONZE|2019-11-20
 *
 * Output (application/json):
 * [
 *   {
 *     "customerId": "CUST-001",
 *     "name": "John Doe",
 *     "email": "john@example.com",
 *     "tier": "GOLD",
 *     "memberSince": "2020-01-15",
 *     "addresses": [
 *       { "street": "123 Main St", "city": "Austin", "state": "TX", "zip": "78701" },
 *       { "street": "456 Oak Ave", "city": "Austin", "state": "TX", "zip": "78702" }
 *     ]
 *   },
 *   ...
 * ]
 */
%dw 2.0
output application/json

// Parse each line into fields
var records = (payload as String splitBy "\n")
    filter !isEmpty(trim($))
    map (line) -> do {
        var fields = line splitBy "|"
        ---
        {
            customerId: trim(fields[0]),
            name: trim(fields[1]),
            email: trim(fields[2]),
            street: trim(fields[3]),
            city: trim(fields[4]),
            state: trim(fields[5]),
            zip: trim(fields[6]),
            tier: trim(fields[7]),
            memberSince: trim(fields[8])
        }
    }
---
// Group by customer and nest addresses
records groupBy $.customerId
    pluck (customerRecords, customerId) -> do {
        var first = customerRecords[0]
        ---
        {
            customerId: customerId as String,
            name: first.name,
            email: first.email,
            tier: first.tier,
            memberSince: first.memberSince,
            addresses: customerRecords map (rec) -> {
                street: rec.street,
                city: rec.city,
                state: rec.state,
                zip: rec.zip
            }
        }
    }

// Alternative — simple flat transform without grouping:
// records map (rec) -> rec - "street" - "city" - "state" - "zip"
//     ++ { address: { street: rec.street, city: rec.city, state: rec.state, zip: rec.zip } }
