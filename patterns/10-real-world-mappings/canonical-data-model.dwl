/**
 * Pattern: Canonical Data Model
 * Category: Real-World Mappings
 * Difficulty: Advanced
 *
 * Description: Normalize data from multiple source systems into a single
 * canonical (standard) format. The canonical data model pattern reduces
 * point-to-point mappings from N*M to N+M by establishing a common
 * intermediate format. Each source maps TO canonical, each target maps
 * FROM canonical.
 *
 * Input (application/json):
 * {
 *   "source": "salesforce",
 *   "salesforceRecord": {
 *     "Id": "001Dn00000XYZ789",
 *     "Name": "Acme Corporation",
 *     "BillingStreet": "123 Innovation Drive",
 *     "BillingCity": "San Francisco",
 *     "BillingState": "CA",
 *     "BillingPostalCode": "94102",
 *     "BillingCountryCode": "US",
 *     "Phone": "+1-555-0100",
 *     "Website": "https://acme.com",
 *     "Industry": "Technology",
 *     "CreatedDate": "2025-03-10T08:00:00.000Z",
 *     "LastModifiedDate": "2026-02-14T16:45:00.000Z"
 *   },
 *   "sapRecord": {
 *     "KUNNR": "0000012345",
 *     "NAME1": "Globex International",
 *     "STRAS": "456 Commerce Blvd",
 *     "ORT01": "Austin",
 *     "REGIO": "TX",
 *     "PSTLZ": "73301",
 *     "LAND1": "US",
 *     "TELF1": "+1-555-0200",
 *     "BRSCH": "TECH",
 *     "ERDAT": "20240815",
 *     "LAEDA": "20260210"
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "canonical": {
 *     "entity": "Organization",
 *     "version": "1.0",
 *     "id": {
 *       "canonical": "ORG-salesforce-001Dn00000XYZ789",
 *       "sourceSystem": "salesforce",
 *       "sourceId": "001Dn00000XYZ789"
 *     },
 *     "name": "Acme Corporation",
 *     "address": {
 *       "street": "123 Innovation Drive",
 *       "city": "San Francisco",
 *       "state": "CA",
 *       "postalCode": "94102",
 *       "country": "US"
 *     },
 *     "phone": "+1-555-0100",
 *     "website": "https://acme.com",
 *     "industry": "Technology",
 *     "createdAt": "2025-03-10T08:00:00Z",
 *     "updatedAt": "2026-02-14T16:45:00Z"
 *   }
 * }
 */
%dw 2.0
output application/json

var sapIndustryMap = {
    "TECH": "Technology",
    "HLTH": "Healthcare",
    "FINA": "Finance",
    "MANU": "Manufacturing",
    "RETL": "Retail"
}

fun fromSalesforce(record: Object): Object = {
    entity: "Organization",
    version: "1.0",
    id: {
        canonical: "ORG-salesforce-" ++ record.Id,
        sourceSystem: "salesforce",
        sourceId: record.Id
    },
    name: record.Name,
    address: {
        street: record.BillingStreet default "",
        city: record.BillingCity default "",
        state: record.BillingState default "",
        postalCode: record.BillingPostalCode default "",
        country: record.BillingCountryCode default ""
    },
    phone: record.Phone default "",
    website: record.Website default "",
    industry: record.Industry default "Unknown",
    createdAt: record.CreatedDate,
    updatedAt: record.LastModifiedDate
}

fun fromSAP(record: Object): Object = {
    entity: "Organization",
    version: "1.0",
    id: {
        canonical: "ORG-sap-" ++ trim(record.KUNNR),
        sourceSystem: "sap",
        sourceId: trim(record.KUNNR)
    },
    name: trim(record.NAME1),
    address: {
        street: trim(record.STRAS) default "",
        city: trim(record.ORT01) default "",
        state: trim(record.REGIO) default "",
        postalCode: trim(record.PSTLZ) default "",
        country: trim(record.LAND1) default ""
    },
    phone: trim(record.TELF1) default "",
    website: "",
    industry: sapIndustryMap[record.BRSCH] default "Unknown",
    createdAt: (record.ERDAT as Date {format: "yyyyMMdd"}) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"} default "",
    updatedAt: (record.LAEDA as Date {format: "yyyyMMdd"}) as String {format: "yyyy-MM-dd'T'HH:mm:ssXXX"} default ""
}
---
{
    canonical: payload.source match {
        case "salesforce" -> fromSalesforce(payload.salesforceRecord)
        case "sap" -> fromSAP(payload.sapRecord)
        else -> {error: "Unknown source system: $(payload.source)"}
    }
}

// The canonical model approach:
//
// Source A ──→ Canonical ──→ Target X
// Source B ──→ Canonical ──→ Target Y
// Source C ──→ Canonical ──→ Target Z
//
// Without canonical: N sources × M targets = N×M mappings (e.g., 3×3 = 9)
// With canonical: N + M mappings (e.g., 3+3 = 6)
// At scale (10 systems): 100 vs 20 mappings

// Alternative — add a new source system by adding one function:
// fun fromHubSpot(record: Object): Object = {
//     entity: "Organization",
//     version: "1.0",
//     id: {canonical: "ORG-hubspot-" ++ record.companyId, ...},
//     name: record.name,
//     ...
// }
