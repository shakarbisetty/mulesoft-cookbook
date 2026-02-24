# Connectors

Production-grade connector recipes for enterprise integrations in MuleSoft. Each recipe includes working Mule XML configurations, DataWeave transformations, and real-world gotchas.

## Recipes

| Recipe | Description |
|--------|-------------|
| [SAP IDoc Processing](sap-idoc-processing/) | SAP IDoc inbound/outbound processing via MuleSoft SAP connector |
| [Workday Custom Reports](workday-custom-reports/) | Pull custom reports from Workday via RaaS (Report as a Service) |
| [ServiceNow CMDB](servicenow-cmdb/) | ServiceNow CMDB integration for asset management |
| [NetSuite Patterns](netsuite-patterns/) | NetSuite SuiteScript/REST patterns for financial integrations |
| [Database CDC](database-cdc/) | Database Change Data Capture without dedicated CDC tools |
| [SFTP Guaranteed Delivery](sftp-guaranteed-delivery/) | SFTP file transfers with exactly-once delivery guarantee |
| [EDI Processing](edi-processing/) | EDI X12 and EDIFACT message processing |
| [AS2 Exchange](as2-exchange/) | AS2 message exchange for B2B |

## When to Use These Recipes

- **ERP Integrations**: SAP IDoc, NetSuite for back-office connectivity
- **HCM / ITSM**: Workday reports, ServiceNow CMDB for HR and IT operations
- **B2B / EDI**: EDI X12/EDIFACT processing, AS2 message exchange for trading partners
- **File-Based**: SFTP guaranteed delivery for legacy file-based integrations
- **Data Sync**: Database CDC for near-real-time change propagation without middleware

## Prerequisites

- Anypoint Studio 7.x or Anypoint Code Builder
- Mule Runtime 4.4+ (4.6+ recommended)
- Connector licenses as required (SAP, Workday, ServiceNow, NetSuite, EDI, AS2)
- Anypoint Platform account for connector access via Exchange
