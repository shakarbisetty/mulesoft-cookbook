## NetSuite Integration Patterns

> NetSuite SuiteScript/REST patterns for financial integrations with token-based auth, saved searches, and custom record operations.

### When to Use

- Integrating order-to-cash or procure-to-pay processes between NetSuite and external systems
- Extracting financial data (invoices, journal entries, vendor bills) for reporting or data warehouse
- Synchronizing customer/vendor master data across ERP and CRM
- Executing saved searches programmatically for complex financial queries
- Performing CRUD on custom records for industry-specific extensions

### Configuration

#### NetSuite Connector with Token-Based Auth (TBA)

```xml
<netsuite:config name="NetSuite_Config" doc:name="NetSuite Config">
    <netsuite:token-authentication-connection
        consumerKey="${netsuite.consumerKey}"
        consumerSecret="${netsuite.consumerSecret}"
        tokenId="${netsuite.tokenId}"
        tokenSecret="${netsuite.tokenSecret}"
        accountId="${netsuite.accountId}" />
</netsuite:config>
```

#### Alternative: SuiteQL via REST (HTTP Connector)

```xml
<http:request-config name="NetSuite_REST_Config" doc:name="NetSuite REST">
    <http:request-connection
        host="${netsuite.accountId}.suitetalk.api.netsuite.com"
        port="443"
        protocol="HTTPS">
        <http:authentication>
            <http:custom-authentication>
                <!-- OAuth 1.0 header built via DataWeave -->
            </http:custom-authentication>
        </http:authentication>
    </http:request-connection>
</http:request-config>
```

#### Saved Search Execution

```xml
<flow name="netsuite-saved-search-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/netsuite/invoices"
        allowedMethods="GET" />

    <netsuite:search config-ref="NetSuite_Config"
        doc:name="Execute Saved Search"
        searchType="TransactionSearchAdvanced"
        savedSearchId="${netsuite.invoiceSearchId}">
        <netsuite:criteria><![CDATA[#[output application/xml
---
{
    "platformMsgs:search" @(
        "xmlns:platformMsgs": "urn:messages_2021_2.platform.webservices.netsuite.com",
        "xmlns:tranSales": "urn:sales_2021_2.transactions.webservices.netsuite.com"
    ): {
        "platformMsgs:searchRecord" @(
            "xsi:type": "tranSales:TransactionSearchAdvanced",
            savedSearchId: vars.savedSearchId
        ): {
            criteria: {
                basic: {
                    "type" @(operator: "anyOf"): {
                        searchValue: "Invoice"
                    },
                    dateCreated @(operator: "within"): {
                        searchValue: vars.fromDate,
                        searchValue2: vars.toDate
                    }
                }
            }
        }
    }
}]]]></netsuite:criteria>
    </netsuite:search>

    <ee:transform doc:name="Map Invoices">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
payload.searchResult.searchRowList.*searchRow map {
    internalId: $.basic.internalId.searchValue.@internalId,
    tranId: $.basic.tranId.searchValue,
    entity: $.basic.entity.searchValue.@internalId,
    tranDate: $.basic.tranDate.searchValue,
    amount: $.basic.amount.searchValue as Number,
    status: $.basic.status.searchValue,
    currency: $.basic.currency.searchValue.name
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

#### Paginated Search with More Results

```xml
<flow name="netsuite-paginated-search-flow">
    <netsuite:search config-ref="NetSuite_Config"
        doc:name="Initial Search"
        searchType="TransactionSearchAdvanced"
        fetchSize="100" />

    <set-variable variableName="allResults" value="#[payload.searchResult.searchRowList.*searchRow]" />
    <set-variable variableName="totalPages" value="#[payload.searchResult.totalPages]" />
    <set-variable variableName="searchId" value="#[payload.searchResult.searchId]" />
    <set-variable variableName="currentPage" value="#[2]" />

    <choice doc:name="Has More Pages?">
        <when expression="#[vars.totalPages > 1]">
            <flow-ref name="netsuite-fetch-remaining-pages" />
        </when>
    </choice>
</flow>

<sub-flow name="netsuite-fetch-remaining-pages">
    <until-successful maxRetries="3" millisBetweenRetries="3000">
        <netsuite:search-more-with-id config-ref="NetSuite_Config"
            doc:name="Fetch Next Page"
            searchId="#[vars.searchId]"
            pageIndex="#[vars.currentPage]" />
    </until-successful>

    <set-variable variableName="allResults"
        value="#[vars.allResults ++ payload.searchResult.searchRowList.*searchRow]" />

    <choice>
        <when expression="#[vars.currentPage &lt; vars.totalPages]">
            <set-variable variableName="currentPage"
                value="#[vars.currentPage + 1]" />
            <flow-ref name="netsuite-fetch-remaining-pages" />
        </when>
    </choice>
</sub-flow>
```

#### Custom Record CRUD

```xml
<!-- Create Custom Record -->
<flow name="netsuite-create-custom-record-flow">
    <http:listener config-ref="HTTP_Listener"
        path="/api/netsuite/custom-records"
        allowedMethods="POST" />

    <ee:transform doc:name="Build Custom Record">
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/xml
ns customization urn:customization_2021_2.setup.webservices.netsuite.com
ns platformCore urn:core_2021_2.platform.webservices.netsuite.com
---
{
    customization#CustomRecord @(
        "xsi:type": "customization:CustomRecord",
        recType @(internalId: vars.customRecordTypeId): {}
    ): {
        customization#name: payload.name,
        platformCore#customFieldList: {
            (payload.fields map ((field) ->
                platformCore#customField @(
                    "xsi:type": "platformCore:StringCustomFieldRef",
                    scriptId: field.scriptId
                ): {
                    platformCore#value: field.value
                }
            ))
        }
    }
}]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <netsuite:add-record config-ref="NetSuite_Config"
        doc:name="Create Custom Record" />
</flow>

<!-- Update Custom Record -->
<flow name="netsuite-update-custom-record-flow">
    <netsuite:update-record config-ref="NetSuite_Config"
        doc:name="Update Custom Record"
        internalId="#[payload.internalId]"
        type="CustomRecord"
        customRecordTypeId="#[vars.customRecordTypeId]" />
</flow>
```

#### DataWeave: NetSuite XML to Standard JSON

```dataweave
%dw 2.0
output application/json

// Flatten NetSuite's deeply nested SOAP response into clean JSON
fun mapLineItems(items) =
    items.*item map {
        line: $.line as Number,
        itemId: $.item.@internalId,
        itemName: $.item.name,
        quantity: $.quantity as Number default 0,
        rate: $.rate as Number default 0,
        amount: $.amount as Number default 0,
        taxCode: $.taxCode.@internalId default null,
        department: $.department.@internalId default null,
        location: $.location.@internalId default null
    }

fun mapAddress(addr) =
    if (addr != null) {
        line1: addr.addr1,
        line2: addr.addr2 default null,
        city: addr.city,
        state: addr.state,
        zip: addr.zip,
        country: addr.country
    } else null
---
{
    invoice: {
        internalId: payload.@internalId,
        tranId: payload.tranId,
        status: payload.status,
        entity: {
            id: payload.entity.@internalId,
            name: payload.entity.name
        },
        tranDate: payload.tranDate as Date {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"},
        dueDate: payload.dueDate as Date {format: "yyyy-MM-dd'T'HH:mm:ss.SSSZ"} default null,
        currency: payload.currency.name,
        exchangeRate: payload.exchangeRate as Number default 1,
        subtotal: payload.subTotal as Number,
        taxTotal: payload.taxTotal as Number default 0,
        total: payload.total as Number,
        billingAddress: mapAddress(payload.billingAddress),
        lineItems: mapLineItems(payload.itemList),
        customFields: payload.customFieldList.*customField map {
            scriptId: $.@scriptId,
            value: $.value
        }
    }
}
```

### How It Works

1. **Token-based auth** — The NetSuite connector uses OAuth 1.0 TBA (Token-Based Authentication) with consumer key/secret and token ID/secret. No session management needed
2. **Saved search** — The connector executes a pre-built saved search by ID, which runs server-side in NetSuite and returns structured result rows
3. **Pagination** — NetSuite returns results in pages (default 1000 per page). Use `searchMoreWithId` with the search session ID and page index to fetch subsequent pages
4. **Custom records** — NetSuite custom record types have a `recType` internal ID. CRUD operations reference both the record's internal ID and the record type ID
5. **SuiteQL alternative** — For complex queries, SuiteQL (NetSuite's SQL-like language) via the REST API is often simpler than the SOAP-based saved search approach

### API Comparison

| Approach | Best For | Limitations |
|----------|----------|-------------|
| SuiteTalk (SOAP) | Full CRUD, saved searches, complex transactions | Verbose XML, slower, pagination complexity |
| REST / SuiteQL | Ad-hoc queries, simple CRUD, modern integrations | Limited transaction support, newer (may lack features) |
| RESTlet (SuiteScript) | Custom logic, complex business rules server-side | Requires SuiteScript development, governance limits |

### Gotchas

- **Concurrent request limits** — NetSuite enforces a per-account concurrency limit (typically 5-10 concurrent web service requests depending on license tier). Exceeding this returns `CONCURRENT_LIMIT_EXCEEDED`. Implement request queuing or throttling in MuleSoft
- **SuiteTalk vs REST vs SuiteQL** — SuiteTalk (SOAP) is the most mature API but verbose. REST is simpler but does not support all record types. SuiteQL is powerful for reads but does not support writes. Choose based on your operation type
- **Sandbox refresh impacts** — NetSuite sandbox accounts are refreshed from production periodically, which resets TBA tokens and custom record configurations. Automate token provisioning or maintain a post-refresh setup script
- **Search session expiry** — NetSuite search sessions for paginated results expire after 15 minutes of inactivity. If you have slow processing between pages, the session times out and you must restart the search from page 1
- **Governance limits** — RESTlets and SuiteScript have governance unit limits. A single search operation might consume 10 units; complex scripts can hit the 10,000 unit cap. Monitor governance usage in the NetSuite Execution Log
- **Date/timezone handling** — NetSuite stores dates in the company's timezone but returns them in Pacific Time (PT) via the API unless explicitly configured. Always convert to UTC in your DataWeave transformations
- **Custom field script IDs** — Custom fields are referenced by `scriptId` (e.g., `custbody_my_field`), not by label. Script IDs are case-sensitive and must match exactly

### Related

- [SAP IDoc Processing](../sap-idoc-processing/) — Similar ERP integration patterns for SAP
- [Workday Custom Reports](../workday-custom-reports/) — Enterprise connector with comparable pagination handling
- [Database CDC](../database-cdc/) — For incremental sync from NetSuite using saved search date filters
