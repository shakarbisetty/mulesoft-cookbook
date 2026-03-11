/**
 * Pattern: Salesforce to SAP Mapping
 * Category: Real-World Mappings
 * Difficulty: Advanced
 * Description: Map Salesforce Account and Contact objects to SAP Business
 * Partner (BAPI) IDoc format. One of the most common enterprise integration
 * scenarios — syncing customer master data between CRM and ERP. Handles
 * field renaming, type coercion, default values, and structural transformation.
 *
 * Input (application/json):
 * {
 *   "Account": {
 *     "Id": "001Dn00000ABC123",
 *     "Name": "Acme Corporation",
 *     "BillingStreet": "123 Innovation Drive",
 *     "BillingCity": "San Francisco",
 *     "BillingState": "CA",
 *     "BillingPostalCode": "94102",
 *     "BillingCountry": "United States",
 *     "Phone": "+1-555-0100",
 *     "Industry": "Technology",
 *     "AnnualRevenue": 5000000,
 *     "NumberOfEmployees": 250,
 *     "Type": "Customer - Direct"
 *   }
 * }
 *
 * Output (application/json):
 * {
 * "IDOC": {
 * "HEADER": {
 * "PARTNER_TYPE": "KU",
 * "PARTNER_ROLE": "AG",
 * "PARTNER_NAME": "Acme Corporation",
 * "EXTERNAL_ID": "SF-001Dn00000ABC123",
 * "INDUSTRY_KEY": "TECH",
 * "PARTNER_CLASS": "CUSTOMER"
 * },
 * "ADDRESS": {
 * "STREET": "123 Innovation Drive",
 * "CITY": "San Francisco",
 * "REGION": "CA",
 * "POSTAL_CODE": "94102",
 * "COUNTRY": "US",
 * "TELEPHONE": "+1-555-0100"
 * },
 * "COMPANY_DATA": {
 * "ANNUAL_REVENUE": "5000000.00",
 * "CURRENCY": "USD",
 * "EMPLOYEES": "000250"
 * },
 * "CONTACTS": [
 * {"CONTACT_NAME": "Chen, Alice", "FUNCTION": "VP of Procurement", "EMAIL": "alice@acme.com", "TELEPHONE": "+1-555-0142"},
 * {"CONTACT_NAME": "Martinez, Bob", "FUNCTION": "IT Director", "EMAIL": "bob@acme.com", "TELEPHONE": "+1-555-0155"}
 * ]
 * }
 * }
 */
%dw 2.0
output application/json
var acct = payload.Account
var industryMap = { "Technology": "TECH", "Finance": "FINA", "Healthcare": "HLTH", "Manufacturing": "MFGR" }
---
{
    IDOC: {
        HEADER: {
            PARTNER_TYPE: "KU",
            PARTNER_ROLE: "AG",
            PARTNER_NAME: acct.Name,
            EXTERNAL_ID: "SF-" ++ acct.Id,
            INDUSTRY_KEY: industryMap[acct.Industry] default "OTHR"
        },
        ADDRESS: {
            STREET: acct.BillingStreet,
            CITY: acct.BillingCity,
            REGION: acct.BillingState,
            POSTAL_CODE: acct.BillingPostalCode
        }
    }
}
