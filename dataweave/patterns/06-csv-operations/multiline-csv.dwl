/**
 * Pattern: Multi-line CSV Fields
 * Category: CSV Operations
 * Difficulty: Intermediate
 *
 * Description: Handle CSV data where fields contain newlines, commas,
 * or quotes within quoted values. Properly parse and generate CSV with
 * embedded special characters — a common issue with address fields,
 * descriptions, and notes from CRM/ERP exports.
 *
 * Input (application/csv):
 * name,address,notes
 * "John Doe","123 Main St
 * Apt 4B
 * Austin, TX 78701","First-time buyer, needs ""premium"" support"
 * "Jane Smith","456 Oak Ave, Suite 100
 * New York, NY 10001","VIP customer"
 *
 * Output (application/json):
 * [
 *   {
 *     "name": "John Doe",
 *     "address": "123 Main St\nApt 4B\nAustin, TX 78701",
 *     "addressLines": ["123 Main St", "Apt 4B", "Austin, TX 78701"],
 *     "notes": "First-time buyer, needs \"premium\" support",
 *     "city": "Austin",
 *     "state": "TX",
 *     "zip": "78701"
 *   },
 *   ...
 * ]
 */
%dw 2.0
output application/json

// DW natively handles RFC 4180 compliant CSV:
// - Fields enclosed in double quotes can contain newlines
// - Double quotes within fields are escaped as ""
// - Commas within quoted fields are treated as data

fun parseAddress(address: String): Object = do {
    var lines = address splitBy "\n" map trim($)
    var lastLine = lines[-1]
    // Parse "City, ST ZIP" from last line
    var cityStateZip = lastLine match /^(.+),\s*([A-Z]{2})\s+(\d{5})$/
    ---
    {
        addressLines: lines,
        city: cityStateZip[1] default lastLine,
        state: cityStateZip[2] default "",
        zip: cityStateZip[3] default ""
    }
}
---
payload map (row) -> do {
    var addressInfo = parseAddress(row.address)
    ---
    {
        name: row.name,
        address: row.address,
        addressLines: addressInfo.addressLines,
        notes: row.notes,
        city: addressInfo.city,
        state: addressInfo.state,
        zip: addressInfo.zip
    }
}

// To GENERATE CSV with multiline fields:
// %dw 2.0
// output application/csv quoteValues=true
// ---
// payload map (item) -> {
//     name: item.name,
//     address: item.addressLines joinBy "\n",
//     notes: item.notes
// }
