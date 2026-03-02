# Connectors

Production-grade connector recipes for enterprise integrations in MuleSoft. Each recipe includes working Mule XML configurations, DataWeave transformations, and real-world gotchas.

## Recipes

### Database

| Recipe | Description |
|--------|-------------|
| [Database CDC](database-cdc/) | Database Change Data Capture without dedicated CDC tools |
| [DB Connection Pool Tuning](db-connection-pool-tuning/) | HikariCP pool sizing, idle connection management, and leak detection |
| [DB Bulk Insert Performance](db-bulk-insert-performance/) | Batch size tuning, parameterized bulk inserts, per-record error handling |

### SAP

| Recipe | Description |
|--------|-------------|
| [SAP IDoc Processing](sap-idoc-processing/) | SAP IDoc inbound/outbound processing via MuleSoft SAP connector |
| [SAP IDoc Processing Complete](sap-idoc-processing-complete/) | Complete IDoc with TID handler, error recovery, and ALE monitoring |
| [SAP JCo CloudHub Deployment](sap-jco-cloudhub-deployment/) | Native library deployment and JCo config on CloudHub |

### Salesforce

| Recipe | Description |
|--------|-------------|
| [SF CDC Idempotent Processing](sf-cdc-idempotent-processing/) | Deduplicate CDC events with replay ID tracking and Object Store watermark |
| [SF Bulk API v2 Optimization](sf-bulk-api-v2-optimization/) | Memory-safe bulk queries with streaming and chunking |
| [SF Governor Limit Patterns](sf-governor-limit-patterns/) | API call counting, circuit breaker when approaching limits |

### HCM / ITSM

| Recipe | Description |
|--------|-------------|
| [Workday Custom Reports](workday-custom-reports/) | Pull custom reports from Workday via RaaS (Report as a Service) |
| [Workday Parallel Pagination](workday-parallel-pagination/) | Parallel SOAP calls for large Workday data syncs |
| [ServiceNow CMDB](servicenow-cmdb/) | ServiceNow CMDB integration for asset management |
| [ServiceNow Incident Lifecycle](servicenow-incident-lifecycle/) | Incident create/update/resolve/close automation |
| [NetSuite Patterns](netsuite-patterns/) | NetSuite SuiteScript/REST patterns for financial integrations |

### HTTP / Network

| Recipe | Description |
|--------|-------------|
| [HTTP mTLS Complete Setup](http-mtls-complete-setup/) | Certificate generation, keystore/truststore, rotation strategy |
| [HTTP Proxy Auth Config](http-proxy-auth-config/) | HTTP proxy with NTLM/Kerberos auth, corporate proxy setup |

### File Transfer

| Recipe | Description |
|--------|-------------|
| [SFTP Guaranteed Delivery](sftp-guaranteed-delivery/) | SFTP file transfers with exactly-once delivery guarantee |
| [SFTP Large File Streaming](sftp-large-file-streaming/) | 300MB+ files without OOM using streaming and watermarking |

### Email

| Recipe | Description |
|--------|-------------|
| [Email OAuth2 O365/Gmail](email-oauth2-o365-gmail/) | OAuth2 for Office 365 and Gmail IMAP/SMTP |

### AWS

| Recipe | Description |
|--------|-------------|
| [AWS S3 Streaming Upload](aws-s3-streaming-upload/) | S3 multipart upload with streaming, presigned URLs |
| [AWS SQS Reliable Consumer](aws-sqs-reliable-consumer/) | SQS visibility timeout, DLQ, FIFO deduplication |

### Azure

| Recipe | Description |
|--------|-------------|
| [Azure Service Bus Patterns](azure-service-bus-patterns/) | Competing consumers, sessions, scheduled delivery |

### B2B

| Recipe | Description |
|--------|-------------|
| [EDI Processing](edi-processing/) | EDI X12 and EDIFACT message processing |
| [AS2 Exchange](as2-exchange/) | AS2 message exchange for B2B |

## When to Use These Recipes

- **ERP Integrations**: SAP IDoc, NetSuite for back-office connectivity
- **HCM / ITSM**: Workday reports, ServiceNow CMDB and incident automation
- **Salesforce**: CDC event processing, bulk operations, governor limit management
- **B2B / EDI**: EDI X12/EDIFACT processing, AS2 message exchange for trading partners
- **File-Based**: SFTP guaranteed delivery and large file streaming
- **Data Sync**: Database CDC, connection pool tuning, bulk insert optimization
- **Cloud Messaging**: AWS SQS, Azure Service Bus for event-driven architectures
- **Security**: mTLS setup, OAuth2 email, proxy authentication
- **Cloud Storage**: AWS S3 streaming uploads and presigned URLs

## Prerequisites

- Anypoint Studio 7.x or Anypoint Code Builder
- Mule Runtime 4.4+ (4.6+ recommended)
- Connector licenses as required (SAP, Workday, ServiceNow, NetSuite, EDI, AS2)
- Anypoint Platform account for connector access via Exchange
- AWS or Azure accounts for cloud connector recipes
