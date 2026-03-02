# Bulk API v2 Chunk Size Calculator

## Problem

Salesforce Bulk API v2 performance varies dramatically based on chunk size and object complexity. Submitting 10,000-record chunks for an object with 15 Apex triggers, 8 validation rules, and 3 workflow rules causes governor limit failures and cascading timeouts. Conversely, using tiny 200-record chunks for simple inserts wastes time on job overhead. Most teams pick an arbitrary chunk size and never tune it, leaving significant performance on the table.

## Solution

Build a DataWeave-powered chunk size calculator that queries object metadata (trigger count, validation rules, field count) and dynamically determines the optimal chunk size. Include a benchmarked lookup table for common scenarios and a splitting utility that partitions payloads before submission.

## Implementation

**Performance Benchmark Reference Table**

| Object Complexity | Triggers | Validation Rules | Recommended Chunk Size | Throughput (records/min) |
|---|---|---|---|---|
| Simple (no automation) | 0 | 0-2 | 10,000 | ~50,000 |
| Low (basic automation) | 1-2 | 1-3 | 5,000 | ~25,000 |
| Medium (standard automation) | 3-5 | 3-5 | 2,000 | ~12,000 |
| High (heavy automation) | 5-10 | 5-10 | 500 | ~4,000 |
| Very High (complex logic) | 10+ | 10+ | 200 | ~1,500 |
| Read-only (query) | N/A | N/A | 50,000 | ~200,000 |

**Chunk Calculator Flow**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:http="http://www.mulesoft.org/schema/mule/http"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Sub-flow: Retrieve Object Metadata for Complexity Scoring -->
    <sub-flow name="get-object-complexity">
        <!-- Query object describe for field count -->
        <http:request method="GET"
                      config-ref="Salesforce_REST_Config"
                      path="/services/data/v59.0/sobjects/#[vars.targetObject]/describe">
            <http:headers>
                #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
            </http:headers>
        </http:request>

        <set-variable variableName="objectDescribe" value="#[payload]"/>

        <!-- Query Tooling API for trigger count -->
        <http:request method="GET"
                      config-ref="Salesforce_REST_Config"
                      path="/services/data/v59.0/tooling/query">
            <http:query-params>
                #[{'q': "SELECT COUNT() FROM ApexTrigger WHERE TableEnumOrId = '" ++ vars.targetObject ++ "' AND Status = 'Active'"}]
            </http:query-params>
            <http:headers>
                #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
            </http:headers>
        </http:request>

        <set-variable variableName="triggerCount" value="#[payload.totalSize]"/>

        <!-- Query for validation rules -->
        <http:request method="GET"
                      config-ref="Salesforce_REST_Config"
                      path="/services/data/v59.0/tooling/query">
            <http:query-params>
                #[{'q': "SELECT COUNT() FROM ValidationRule WHERE EntityDefinition.QualifiedApiName = '" ++ vars.targetObject ++ "' AND Active = true"}]
            </http:query-params>
            <http:headers>
                #[{'Authorization': 'Bearer ' ++ vars.sfAccessToken}]
            </http:headers>
        </http:request>

        <set-variable variableName="validationRuleCount" value="#[payload.totalSize]"/>
    </sub-flow>

    <!-- Sub-flow: Calculate Optimal Chunk Size -->
    <sub-flow name="calculate-chunk-size">
        <flow-ref name="get-object-complexity"/>

        <ee:transform doc:name="Compute Optimal Chunk Size">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

var triggerCount = vars.triggerCount as Number
var validationCount = vars.validationRuleCount as Number
var fieldCount = sizeOf(vars.objectDescribe.fields default [])
var operation = vars.bulkOperation default "insert"

// Complexity score: 0-100 scale
var triggerScore = min([triggerCount * 10, 50])
var validationScore = min([validationCount * 5, 25])
var fieldScore = if (fieldCount > 100) 15
                else if (fieldCount > 50) 10
                else if (fieldCount > 20) 5
                else 0
// Flows and Process Builder add hidden overhead
var automationScore = triggerScore + validationScore + fieldScore

// Map score to chunk size
var chunkSize = automationScore match {
    case s if s == 0  -> 10000
    case s if s <= 15 -> 5000
    case s if s <= 30 -> 2000
    case s if s <= 50 -> 500
    else              -> 200
}

// Read operations can always use larger chunks
var finalChunkSize = if (operation == "query") 50000
                     else chunkSize

// Calculate estimated job count and timing
var totalRecords = vars.totalRecords as Number default 0
var estimatedJobs = if (totalRecords > 0)
    ceil(totalRecords / finalChunkSize)
    else 0
var estimatedMinutes = estimatedJobs * 2  // ~2 min per chunk average

---
{
    object: vars.targetObject,
    operation: operation,
    complexity: {
        triggerCount: triggerCount,
        validationRuleCount: validationCount,
        fieldCount: fieldCount,
        automationScore: automationScore,
        level: automationScore match {
            case s if s == 0  -> "SIMPLE"
            case s if s <= 15 -> "LOW"
            case s if s <= 30 -> "MEDIUM"
            case s if s <= 50 -> "HIGH"
            else              -> "VERY_HIGH"
        }
    },
    recommendation: {
        chunkSize: finalChunkSize,
        estimatedJobs: estimatedJobs,
        estimatedMinutes: estimatedMinutes,
        parallelJobsAllowed: if (finalChunkSize <= 500) 1 else min([5, estimatedJobs])
    }
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </sub-flow>

    <!-- Main flow: Dynamic Chunking and Submission -->
    <flow name="dynamic-chunk-bulk-load">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/bulk-load-smart"
                       method="POST"/>

        <set-variable variableName="targetObject" value="#[attributes.queryParams.object]"/>
        <set-variable variableName="bulkOperation" value="#[attributes.queryParams.operation default 'insert']"/>
        <set-variable variableName="totalRecords" value="#[sizeOf(payload)]"/>

        <!-- Calculate optimal chunk size -->
        <flow-ref name="calculate-chunk-size"/>
        <set-variable variableName="chunkConfig" value="#[payload]"/>
        <set-variable variableName="chunkSize"
                      value="#[payload.recommendation.chunkSize]"/>

        <logger level="INFO"
                message='Object: #[vars.targetObject], Complexity: #[vars.chunkConfig.complexity.level], Chunk size: #[vars.chunkSize], Estimated jobs: #[vars.chunkConfig.recommendation.estimatedJobs]'/>

        <!-- Split payload into calculated chunks -->
        <set-payload value="#[vars.originalPayload]"/>

        <ee:transform doc:name="Split Into Chunks">
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json

// Recursive chunk splitter
fun splitChunks(arr, size, acc = []) =
    if (isEmpty(arr)) acc
    else splitChunks(arr[size to -1] default [], size,
                     acc << arr[0 to size - 1])
---
{
    chunks: splitChunks(payload, vars.chunkSize as Number),
    totalChunks: ceil(sizeOf(payload) / (vars.chunkSize as Number)),
    chunkSize: vars.chunkSize
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <!-- Process each chunk as a separate Bulk API v2 job -->
        <foreach collection="#[payload.chunks]">
            <salesforce:create-job config-ref="Salesforce_Config">
                <salesforce:create-job-request>
                    <salesforce:job-info
                        object="#[vars.targetObject]"
                        operation="#[vars.bulkOperation]"
                        contentType="CSV"
                        lineEnding="LF"/>
                </salesforce:create-job-request>
            </salesforce:create-job>

            <logger level="INFO"
                    message='Submitted chunk #[vars.counter] of #[vars.chunkConfig.recommendation.estimatedJobs] (#[sizeOf(payload)] records)'/>
        </foreach>

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                        message='Chunk load failed at chunk #[vars.counter default "unknown"]: #[error.description]'/>
            </on-error-propagate>
        </error-handler>
    </flow>
</mule>
```

## How It Works

1. **Metadata query**: The flow queries the Salesforce Tooling API to count active Apex triggers and validation rules for the target object, and uses `/describe` to get the field count.
2. **Complexity scoring**: A weighted formula produces an automation score (0-100): triggers contribute up to 50 points, validation rules up to 25, and field count up to 15. Higher scores indicate heavier server-side processing per record.
3. **Chunk size mapping**: The automation score maps to a chunk size tier. Simple objects with no automation get 10,000-record chunks; heavily automated objects get 200-record chunks.
4. **Dynamic splitting**: A recursive DataWeave function splits the payload into chunks of the calculated size without loading the entire dataset into memory twice.
5. **Sequential submission**: Each chunk is submitted as an independent Bulk API v2 job, allowing Salesforce to process them with proper governor limit budgets.

## Key Takeaways

- Never use a one-size-fits-all chunk size. The difference between 200 and 10,000 records per chunk can be a 10x throughput difference.
- Query operations can safely use 50,000-record chunks because they do not trigger Apex, validation rules, or workflows.
- The Tooling API calls to count triggers and validation rules add 3 API calls to the initial setup, but save hundreds of failed records from governor limit errors.
- Cache the complexity score for each object (per org) since metadata rarely changes; refresh it on deployment.
- For objects with Process Builder or Flows, add additional scoring weight since these are harder to count via API.

## Related Recipes

- [Bulk API 2.0 Partial Failure Recovery](../bulk-api-2-partial-failure/)
- [Bulk API v2 Job Orchestrator](../bulk-api-v2-job-orchestrator/)
- [Governor Limit Safe Batch Processing](../governor-limit-safe-batch/)
- [SF API Quota Monitoring](../sf-api-quota-monitoring/)
