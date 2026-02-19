/**
 * Pattern: Multi-Record Flat File
 * Category: Flat File & Fixed-Width
 * Difficulty: Advanced
 *
 * Description: Parse flat files with multiple record types identified by
 * a type indicator in the first position(s). Common in banking (ACH, BAI2),
 * insurance, and EDI-like formats with header, detail, and trailer records.
 *
 * Input (text/plain):
 * H20260218ACME CORP        BATCH-001
 * D001John Doe          0000095000ENG
 * D002Jane Smith         0000082000MKT
 * D003Bob Johnson        0000078500SAL
 * T003000000255500
 *
 * Record types:
 *   H = Header: date(8), company(18), batchId(9)
 *   D = Detail: seqNum(3), name(18), amount(10), dept(3)
 *   T = Trailer: recordCount(3), totalAmount(12)
 *
 * Output (application/json):
 * {
 *   "header": {
 *     "date": "2026-02-18",
 *     "company": "ACME CORP",
 *     "batchId": "BATCH-001"
 *   },
 *   "records": [
 *     { "seq": 1, "name": "John Doe", "amount": 95000, "dept": "ENG" },
 *     { "seq": 2, "name": "Jane Smith", "amount": 82000, "dept": "MKT" },
 *     { "seq": 3, "name": "Bob Johnson", "amount": 78500, "dept": "SAL" }
 *   ],
 *   "trailer": {
 *     "recordCount": 3,
 *     "totalAmount": 255500
 *   },
 *   "validation": {
 *     "countMatch": true,
 *     "totalMatch": true
 *   }
 * }
 */
%dw 2.0
output application/json

var lines = (payload as String splitBy "\n") filter !isEmpty(trim($))

fun parseHeader(line: String): Object = {
    date: "$(line[1 to 4])-$(line[5 to 6])-$(line[7 to 8])",
    company: trim(line[9 to 26]),
    batchId: trim(line[27 to 35])
}

fun parseDetail(line: String): Object = {
    seq: (line[1 to 3] as Number),
    name: trim(line[4 to 21]),
    amount: (trim(line[22 to 31]) as Number),
    dept: trim(line[32 to 34])
}

fun parseTrailer(line: String): Object = {
    recordCount: (line[1 to 3] as Number),
    totalAmount: (trim(line[4 to 15]) as Number)
}

var header = parseHeader((lines filter $[0] == "H")[0])
var details = lines filter $[0] == "D" map parseDetail($)
var trailer = parseTrailer((lines filter $[0] == "T")[0])
---
{
    header: header,
    records: details,
    trailer: trailer,
    validation: {
        countMatch: trailer.recordCount == sizeOf(details),
        totalMatch: trailer.totalAmount == sum(details.amount)
    }
}
