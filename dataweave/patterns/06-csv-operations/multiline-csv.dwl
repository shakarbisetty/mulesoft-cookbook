/**
 * Pattern: Multi-line CSV Fields
 * Category: CSV Operations
 * Difficulty: Intermediate
 * Description: Handle CSV data where fields contain newlines, commas,
 * or quotes within quoted values. Properly parse and generate CSV with
 * embedded special characters — a common issue with address fields,
 * descriptions, and notes from CRM/ERP exports.
 *
 * Input (application/json):
 * [
 *   {
 *     "name": "Alice",
 *     "address": "123 Main St\nApt 4\nSpringfield, IL 62704"
 *   },
 *   {
 *     "name": "Bob",
 *     "address": "456 Oak Ave\nSuite 200\nChicago, IL 60601"
 *   }
 * ]
 *
 * Output (application/json):
 * [
 * {
 * "name": "John Doe",
 * "address": "123 Main St\nApt 4B\nAustin, TX 78701",
 * "addressLines": ["123 Main St", "Apt 4B", "Austin, TX 78701"],
 * "notes": "First-time buyer, needs \"premium\" support",
 * "city": "Austin",
 * "state": "TX",
 * "zip": "78701"
 * },
 * ...
 * ]
 */
%dw 2.0
output application/json
fun parseAddress(address: String): Object = do {
    var lines = address splitBy "\n" map trim($)
    var lastLine = lines[-1]
    var cityStateZip = lastLine match /^(.+),\s*([A-Z]{2})\s+(\d{5})$/
    --- { city: cityStateZip[1], state: cityStateZip[2], zip: cityStateZip[3] }
}
---
payload map (row) -> do {
    var addressInfo = parseAddress(row.address)
    --- { name: row.name, city: addressInfo.city, state: addressInfo.state, zip: addressInfo.zip }
}
