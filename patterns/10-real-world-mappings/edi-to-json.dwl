/**
 * Pattern: EDI to JSON
 * Category: Real-World Mappings
 * Difficulty: Advanced
 *
 * Description: Transform parsed EDI (X12/EDIFACT) data into a clean JSON
 * structure. In MuleSoft, EDI is first parsed by the X12/EDIFACT connector
 * into a DataWeave-accessible object. This pattern shows how to map the
 * parsed EDI segments into business-friendly JSON. Uses an X12 850
 * (Purchase Order) as the example.
 *
 * Input (application/json):
 * {
 *   "TransactionSets": {
 *     "v005010": {
 *       "850": [
 *         {
 *           "Heading": {
 *             "BEG_BeginningSegment": {
 *               "BEG01_TransactionSetPurpose": "NE",
 *               "BEG02_PurchaseOrderType": "NE",
 *               "BEG03_PurchaseOrderNumber": "PO-2026-4521",
 *               "BEG05_Date": "20260215"
 *             },
 *             "N1_Loop": [
 *               {
 *                 "N1_PartyIdentification": {
 *                   "N101_EntityIdentifierCode": "BY",
 *                   "N102_Name": "Acme Corporation",
 *                   "N103_IdentificationCodeQualifier": "92",
 *                   "N104_IdentificationCode": "ACME-001"
 *                 }
 *               },
 *               {
 *                 "N1_PartyIdentification": {
 *                   "N101_EntityIdentifierCode": "SE",
 *                   "N102_Name": "Global Supplies Ltd",
 *                   "N103_IdentificationCodeQualifier": "92",
 *                   "N104_IdentificationCode": "GSUP-500"
 *                 }
 *               }
 *             ]
 *           },
 *           "Detail": {
 *             "PO1_Loop": [
 *               {
 *                 "PO1_BaselineItemData": {
 *                   "PO101_AssignedIdentification": "1",
 *                   "PO102_QuantityOrdered": 50,
 *                   "PO103_UnitOfMeasure": "EA",
 *                   "PO104_UnitPrice": 149.99,
 *                   "PO106_ProductId": "SKU-100",
 *                   "PO107_ProductIdQualifier": "VP"
 *                 },
 *                 "PID_ProductDescription": [{"PID05_Description": "Mechanical Keyboard"}]
 *               },
 *               {
 *                 "PO1_BaselineItemData": {
 *                   "PO101_AssignedIdentification": "2",
 *                   "PO102_QuantityOrdered": 100,
 *                   "PO103_UnitOfMeasure": "EA",
 *                   "PO104_UnitPrice": 29.99,
 *                   "PO106_ProductId": "SKU-400",
 *                   "PO107_ProductIdQualifier": "VP"
 *                 },
 *                 "PID_ProductDescription": [{"PID05_Description": "Wireless Mouse"}]
 *               }
 *             ]
 *           }
 *         }
 *       ]
 *     }
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "purchaseOrder": {
 *     "poNumber": "PO-2026-4521",
 *     "poDate": "2026-02-15",
 *     "poType": "New Order",
 *     "buyer": {"name": "Acme Corporation", "id": "ACME-001"},
 *     "seller": {"name": "Global Supplies Ltd", "id": "GSUP-500"},
 *     "lineItems": [
 *       {"lineNumber": 1, "sku": "SKU-100", "description": "Mechanical Keyboard", "quantity": 50, "unit": "EA", "unitPrice": 149.99, "lineTotal": 7499.50},
 *       {"lineNumber": 2, "sku": "SKU-400", "description": "Wireless Mouse", "quantity": 100, "unit": "EA", "unitPrice": 29.99, "lineTotal": 2999.00}
 *     ],
 *     "orderTotal": 10498.50
 *   }
 * }
 */
%dw 2.0
output application/json

var po = payload.TransactionSets.v005010."850"[0]
var heading = po.Heading
var beg = heading.BEG_BeginningSegment
var parties = heading.N1_Loop

var poTypeMap = {
    "NE": "New Order",
    "RO": "Replace Order",
    "CA": "Cancellation"
}

fun findParty(parties: Array, code: String): Object =
    (parties filter $.N1_PartyIdentification.N101_EntityIdentifierCode == code)[0].N1_PartyIdentification default {}

var buyer = findParty(parties, "BY")
var seller = findParty(parties, "SE")

var lineItems = po.Detail.PO1_Loop map (line) -> do {
    var item = line.PO1_BaselineItemData
    ---
    {
        lineNumber: item.PO101_AssignedIdentification as Number,
        sku: item.PO106_ProductId,
        description: (line.PID_ProductDescription[0].PID05_Description) default "",
        quantity: item.PO102_QuantityOrdered,
        unit: item.PO103_UnitOfMeasure,
        unitPrice: item.PO104_UnitPrice,
        lineTotal: item.PO102_QuantityOrdered * item.PO104_UnitPrice
    }
}
---
{
    purchaseOrder: {
        poNumber: beg.BEG03_PurchaseOrderNumber,
        poDate: (beg.BEG05_Date as Date {format: "yyyyMMdd"}) as String {format: "yyyy-MM-dd"},
        poType: poTypeMap[beg.BEG01_TransactionSetPurpose] default "Unknown",
        buyer: {name: buyer.N102_Name, id: buyer.N104_IdentificationCode},
        seller: {name: seller.N102_Name, id: seller.N104_IdentificationCode},
        lineItems: lineItems,
        orderTotal: sum(lineItems.lineTotal)
    }
}

// Alternative 1 — handle multiple transaction sets in one interchange:
// payload.TransactionSets.v005010."850" map (po) -> { purchaseOrder: { ... } }

// Alternative 2 — extract segment data with a reusable helper:
// fun getSegment(loop: Object, segName: String): Object =
//     loop[segName] default {}

// Alternative 3 — add error handling for missing segments:
// var buyer = try(() -> findParty(parties, "BY")) orElse {N102_Name: "Unknown", N104_IdentificationCode: "N/A"}

