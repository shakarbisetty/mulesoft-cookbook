/**
 * Pattern: Flat File to JSON
 * Category: Flat File & Fixed-Width
 * Difficulty: Intermediate
 * Description: Transform a legacy pipe-delimited or fixed-width flat file
 * into a modern JSON structure with proper types, nested objects, and
 * array grouping. Typical for mainframe-to-API modernization projects.
 *
 * Input (text/plain):
 * C001|Alice|alice@mail.com|10 Oak St|Dallas|TX|75001|Gold|2020-01-15
 * C001|Alice|alice@mail.com|22 Elm Ave|Austin|TX|73301|Gold|2020-01-15
 * C002|Bob|bob@mail.com|5 Pine Rd|Miami|FL|33101|Silver|2021-06-10
 * C003|Carol|carol@mail.com|88 Main St|Denver|CO|80201|Bronze|2022-03-22
 * C003|Carol|carol@mail.com|14 Lake Dr|Boulder|CO|80301|Bronze|2022-03-22
 *
 * Output (application/json):
 * [
 * {
 * "customerId": "CUST-001",
 * "name": "John Doe",
 * "email": "john@example.com",
 * "tier": "GOLD",
 * "memberSince": "2020-01-15",
 * "addresses": [
 * { "street": "123 Main St", "city": "Austin", "state": "TX", "zip": "78701" },
 * { "street": "456 Oak Ave", "city": "Austin", "state": "TX", "zip": "78702" }
 * ]
 * },
 * ...
 * ]
 */
%dw 2.0
output application/json
var records = (payload as String splitBy "\n") filter !isEmpty(trim($))
    map (line) -> do { var fields = line splitBy "|" ---
    ({ customerId: trim(fields[0]), name: trim(fields[1]), email: trim(fields[2]), street: trim(fields[3]), city: trim(fields[4]), state: trim(fields[5]), zip: trim(fields[6]), tier: trim(fields[7]) }) }
---
records groupBy $.customerId pluck (recs, cid) -> do {
    var first = recs[0]
    ---
    ({ customerId: cid as String, name: first.name, email: first.email, tier: first.tier, addresses: recs map ({ street: $.street, city: $.city, state: $.state, zip: $.zip }) })
}
