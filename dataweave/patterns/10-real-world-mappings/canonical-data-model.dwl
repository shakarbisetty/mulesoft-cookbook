/**
 * Pattern: Canonical Data Model
 * Category: Real-World Mappings
 * Difficulty: Advanced
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
 *     "Id": "001A000001abc",
 *     "Name": "Acme Corp",
 *     "BillingStreet": "100 Main St",
 *     "BillingCity": "Austin",
 *     "BillingState": "TX",
 *     "BillingPostalCode": "78701",
 *     "Phone": "512-555-0100",
 *     "Website": "https://acme.com",
 *     "Industry": "Technology",
 *     "CreatedDate": "2025-03-15T10:30:00Z"
 *   },
 *   "sapRecord": {
 *     "Id": "SAP-100",
 *     "Name": "SAP Fallback",
 *     "BillingStreet": "N/A",
 *     "BillingCity": "N/A",
 *     "BillingState": "N/A",
 *     "BillingPostalCode": "00000",
 *     "Phone": "000-000-0000",
 *     "Website": "",
 *     "Industry": "Unknown",
 *     "CreatedDate": "2025-01-01T00:00:00Z"
 *   },
 *   "legacyRecord": {
 *     "Id": "LEG-200",
 *     "Name": "Legacy Fallback",
 *     "BillingStreet": "N/A",
 *     "BillingCity": "N/A",
 *     "BillingState": "N/A",
 *     "BillingPostalCode": "00000",
 *     "Phone": "000-000-0000",
 *     "Website": "",
 *     "Industry": "Unknown",
 *     "CreatedDate": "2025-01-01T00:00:00Z"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "canonical": {
 * "entity": "Organization",
 * "version": "1.0",
 * "id": {
 * "canonical": "ORG-salesforce-001Dn00000XYZ789",
 * "sourceSystem": "salesforce",
 * "sourceId": "001Dn00000XYZ789"
 * },
 * "name": "Acme Corporation",
 * "address": {
 * "street": "123 Innovation Drive",
 * "city": "San Francisco",
 * "state": "CA",
 * "postalCode": "94102",
 * "country": "US"
 * },
 * "phone": "+1-555-0100",
 * "website": "https://acme.com",
 * "industry": "Technology",
 * "createdAt": "2025-03-10T08:00:00Z",
 * "updatedAt": "2026-02-14T16:45:00Z"
 * }
 * }
 */
%dw 2.0
output application/json
fun fromSalesforce(rec) = {id: rec.Id, name: rec.Name, address: {street: rec.BillingStreet, city: rec.BillingCity, state: rec.BillingState, zip: rec.BillingPostalCode}, phone: rec.Phone, website: rec.Website, industry: rec.Industry, sourceSystem: "salesforce", mappedAt: now() as String {format: "yyyy-MM-dd'T'HH:mm:ss'Z'"}}
---
payload.source match {"salesforce" -> fromSalesforce(payload.salesforceRecord), "sap" -> fromSalesforce(payload.sapRecord), else -> fromSalesforce(payload.legacyRecord)}
