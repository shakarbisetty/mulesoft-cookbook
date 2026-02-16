/**
 * Pattern: Salesforce to SAP Mapping
 * Category: Real-World Mappings
 * Difficulty: Advanced
 *
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
 *     "Type": "Customer - Direct",
 *     "Contacts": [
 *       {"FirstName": "Alice", "LastName": "Chen", "Email": "alice@acme.com", "Title": "VP of Procurement", "Phone": "+1-555-0142"},
 *       {"FirstName": "Bob", "LastName": "Martinez", "Email": "bob@acme.com", "Title": "IT Director", "Phone": "+1-555-0155"}
 *     ]
 *   }
 * }
 *
 * Output (application/json):
 * {
 *   "IDOC": {
 *     "HEADER": {
 *       "PARTNER_TYPE": "KU",
 *       "PARTNER_ROLE": "AG",
 *       "PARTNER_NAME": "Acme Corporation",
 *       "EXTERNAL_ID": "SF-001Dn00000ABC123",
 *       "INDUSTRY_KEY": "TECH",
 *       "PARTNER_CLASS": "CUSTOMER"
 *     },
 *     "ADDRESS": {
 *       "STREET": "123 Innovation Drive",
 *       "CITY": "San Francisco",
 *       "REGION": "CA",
 *       "POSTAL_CODE": "94102",
 *       "COUNTRY": "US",
 *       "TELEPHONE": "+1-555-0100"
 *     },
 *     "COMPANY_DATA": {
 *       "ANNUAL_REVENUE": "5000000.00",
 *       "CURRENCY": "USD",
 *       "EMPLOYEES": "000250"
 *     },
 *     "CONTACTS": [
 *       {"CONTACT_NAME": "Chen, Alice", "FUNCTION": "VP of Procurement", "EMAIL": "alice@acme.com", "TELEPHONE": "+1-555-0142"},
 *       {"CONTACT_NAME": "Martinez, Bob", "FUNCTION": "IT Director", "EMAIL": "bob@acme.com", "TELEPHONE": "+1-555-0155"}
 *     ]
 *   }
 * }
 */
%dw 2.0
output application/json

var industryMap = {
    "Technology": "TECH",
    "Healthcare": "HLTH",
    "Finance": "FINA",
    "Manufacturing": "MANU",
    "Retail": "RETL"
}

var countryMap = {
    "United States": "US",
    "Canada": "CA",
    "United Kingdom": "GB",
    "Germany": "DE",
    "France": "FR"
}

var acct = payload.Account
---
{
    IDOC: {
        HEADER: {
            PARTNER_TYPE: "KU",
            PARTNER_ROLE: "AG",
            PARTNER_NAME: acct.Name,
            EXTERNAL_ID: "SF-" ++ acct.Id,
            INDUSTRY_KEY: industryMap[acct.Industry] default "OTHR",
            PARTNER_CLASS: "CUSTOMER"
        },
        ADDRESS: {
            STREET: acct.BillingStreet default "",
            CITY: acct.BillingCity default "",
            REGION: acct.BillingState default "",
            POSTAL_CODE: acct.BillingPostalCode default "",
            COUNTRY: countryMap[acct.BillingCountry] default acct.BillingCountry,
            TELEPHONE: acct.Phone default ""
        },
        COMPANY_DATA: {
            ANNUAL_REVENUE: acct.AnnualRevenue as String {format: "0.00"} default "0.00",
            CURRENCY: "USD",
            EMPLOYEES: acct.NumberOfEmployees as String {format: "000000"} default "000000"
        },
        CONTACTS: (acct.Contacts default []) map (contact) -> {
            CONTACT_NAME: "$(contact.LastName), $(contact.FirstName)",
            FUNCTION: contact.Title default "",
            EMAIL: contact.Email default "",
            TELEPHONE: contact.Phone default ""
        }
    }
}

// Alternative 1 — externalize lookup maps to a properties file or ObjectStore:
// var industryMap = vars.industryMappings  // loaded via Mule flow variable
// This keeps the DW code clean and lets ops update mappings without redeployment.

// Alternative 2 — handle multiple Account types:
// var partnerType = acct.Type match {
//     case t if (t contains "Customer") -> "KU"
//     case t if (t contains "Vendor") -> "LI"
//     case t if (t contains "Partner") -> "GP"
//     else -> "KU"
// }

// Alternative 3 — batch mapping (array of Accounts):
// payload.Accounts map (acct) -> { IDOC: { ... } }
