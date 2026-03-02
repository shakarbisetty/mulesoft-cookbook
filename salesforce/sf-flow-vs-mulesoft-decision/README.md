# Salesforce Flow vs MuleSoft Decision Framework

## Problem

Teams building Salesforce integrations frequently debate whether logic should live in Salesforce Flow (or Apex) or in MuleSoft. Choosing wrong leads to maintenance nightmares: Flows that make HTTP callouts to 10 external systems become untestable and hit governor limits, while MuleSoft apps that implement simple field-level validation waste API calls on logic that should run natively in Salesforce. Without a clear decision framework, architecture decisions are made based on team familiarity rather than technical fit, resulting in solutions that are expensive to operate and fragile in production.

## Solution

Provide a scored decision matrix with concrete criteria (data volume, external system count, error handling complexity, monitoring needs, transaction requirements), show where each tool excels with real examples, and identify the anti-patterns that signal the wrong tool was chosen. Include a scoring rubric that teams can apply to their specific use case.

## Implementation

**Decision Matrix**

| Criteria | Weight | Salesforce Flow Wins When... | MuleSoft Wins When... |
|---|---|---|---|
| Data Volume | 20% | < 2,000 records per transaction | > 2,000 records, or streaming/real-time feeds |
| External Systems | 20% | 0-1 external systems | 2+ external systems |
| Transaction Complexity | 15% | Single object CRUD with simple logic | Multi-step orchestration with compensation |
| Error Handling | 15% | Retry and notify is sufficient | Dead letter queues, partial failure recovery needed |
| Monitoring | 10% | Salesforce debug logs are sufficient | Centralized logging, dashboards, alerting required |
| Reusability | 10% | Logic is Salesforce-specific | Logic is shared across multiple systems |
| Latency | 10% | < 120 seconds (Flow timeout) | Long-running processes (minutes to hours) |

**Scoring DataWeave**

```dw
%dw 2.0
output application/json

// Decision scoring engine
// Score each criterion 1-5: 1 = strong Flow fit, 5 = strong MuleSoft fit

var criteria = {
    dataVolume: {
        weight: 0.20,
        scoring: {
            "1": "Under 200 records per transaction",
            "2": "200-2000 records per transaction",
            "3": "2000-10000 records (borderline)",
            "4": "10000-100000 records",
            "5": "Over 100000 records or continuous streaming"
        }
    },
    externalSystems: {
        weight: 0.20,
        scoring: {
            "1": "No external systems (Salesforce-only logic)",
            "2": "One external system with simple REST",
            "3": "Two external systems",
            "4": "Three or more external systems",
            "5": "Complex multi-system orchestration with varying protocols"
        }
    },
    transactionComplexity: {
        weight: 0.15,
        scoring: {
            "1": "Single object create/update",
            "2": "Parent-child operations in same transaction",
            "3": "Multi-object with conditional branching",
            "4": "Saga pattern with compensation logic",
            "5": "Long-running orchestration with human approval steps"
        }
    },
    errorHandling: {
        weight: 0.15,
        scoring: {
            "1": "Show error to user is sufficient",
            "2": "Retry once and notify admin",
            "3": "Automatic retry with backoff",
            "4": "Dead letter queue with reprocessing",
            "5": "Partial failure recovery with per-record error handling"
        }
    },
    monitoring: {
        weight: 0.10,
        scoring: {
            "1": "Salesforce debug logs suffice",
            "2": "Basic email alerts on failure",
            "3": "Centralized logging needed",
            "4": "Real-time dashboards and alerting",
            "5": "SLA tracking, throughput metrics, business KPIs"
        }
    },
    reusability: {
        weight: 0.10,
        scoring: {
            "1": "Logic is entirely Salesforce-specific",
            "2": "Mostly Salesforce with one reusable component",
            "3": "Half Salesforce, half reusable",
            "4": "Mostly reusable across systems",
            "5": "Fully system-agnostic business logic"
        }
    },
    latency: {
        weight: 0.10,
        scoring: {
            "1": "Synchronous, under 5 seconds",
            "2": "Synchronous, under 30 seconds",
            "3": "Up to 120 seconds (Flow timeout limit)",
            "4": "Minutes to complete",
            "5": "Hours or days (batch processing)"
        }
    }
}

// Example scoring for a use case
var exampleScores = {
    dataVolume: 4,
    externalSystems: 4,
    transactionComplexity: 3,
    errorHandling: 4,
    monitoring: 4,
    reusability: 3,
    latency: 3
}

var weightedScore = criteria pluck ((config, key) ->
    config.weight * (exampleScores[key as String] default 3)
) then sum($)

var recommendation = if (weightedScore <= 2.0) "SALESFORCE_FLOW"
                     else if (weightedScore <= 3.0) "EVALUATE_BOTH"
                     else "MULESOFT"
---
{
    criteria: criteria,
    scores: exampleScores,
    weightedScore: weightedScore,
    recommendation: recommendation,
    interpretation: {
        "1.0-2.0": "Strong fit for Salesforce Flow",
        "2.0-3.0": "Borderline — evaluate both options with proof of concept",
        "3.0-5.0": "Strong fit for MuleSoft"
    }
}
```

**Anti-Pattern Detection Flow**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Anti-pattern examples: these are WRONG and should be redesigned -->

    <!-- ANTI-PATTERN 1: MuleSoft doing simple field validation
         This should be a Salesforce validation rule instead.
         Wastes an API call for something SF does natively. -->
    <flow name="antipattern-field-validation-in-mule">
        <!-- DON'T DO THIS -->
        <salesforce:query config-ref="Salesforce_Config">
            <salesforce:salesforce-query>
                SELECT Id, Status__c, Amount__c FROM Opportunity
                WHERE Id = ':id'
            </salesforce:salesforce-query>
        </salesforce:query>

        <!-- Simple validation that belongs in a SF validation rule -->
        <choice>
            <when expression="#[payload.Amount__c &lt; 0]">
                <raise-error type="APP:VALIDATION"
                             description="Amount cannot be negative"/>
            </when>
            <when expression="#[payload.Status__c == null]">
                <raise-error type="APP:VALIDATION"
                             description="Status is required"/>
            </when>
        </choice>
        <!-- INSTEAD: Create a Salesforce Validation Rule:
             AND(Amount__c < 0, true) with error "Amount cannot be negative" -->
    </flow>

    <!-- ANTI-PATTERN 2: Salesforce Flow calling 5+ external APIs
         This should be a MuleSoft orchestration instead.
         Flows have 100 callout limit and 120s timeout. -->
    <!--
    Salesforce Flow design (DON'T DO THIS):
    1. HTTP Callout → ERP system
    2. HTTP Callout → Payment gateway
    3. HTTP Callout → Shipping provider
    4. HTTP Callout → Tax calculator
    5. HTTP Callout → Notification service
    PROBLEM: Any single timeout kills the entire Flow transaction
    INSTEAD: Single callout to MuleSoft API that orchestrates all 5
    -->

    <!-- CORRECT PATTERN: Salesforce calls MuleSoft once,
         MuleSoft orchestrates multiple backends -->
    <flow name="correct-pattern-mule-orchestration">
        <http:listener config-ref="HTTP_Listener_Config"
                       path="/api/process-order"
                       method="POST"/>

        <!-- MuleSoft orchestrates all external calls with proper
             error handling, retry, and timeout management -->
        <scatter-gather>
            <route>
                <http:request config-ref="ERP_Config" path="/api/orders"/>
            </route>
            <route>
                <http:request config-ref="Payment_Config" path="/api/charge"/>
            </route>
            <route>
                <http:request config-ref="Shipping_Config" path="/api/ship"/>
            </route>
        </scatter-gather>

        <!-- Aggregate results and return single response to SF Flow -->
        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    erpOrderId: payload."0".payload.orderId,
    paymentConfirmation: payload."1".payload.confirmationId,
    trackingNumber: payload."2".payload.trackingNumber,
    status: "COMPLETED"
}
                ]]></ee:set-payload>
            </ee:message>
        </ee:transform>
    </flow>
</mule>
```

**Quick Reference: Where Each Tool Excels**

| Use Case | Best Tool | Reason |
|---|---|---|
| Field validation | Salesforce Validation Rule | Zero API cost, instant feedback to user |
| Before-save logic | Salesforce Before-Save Flow | Runs in same transaction, no DML cost |
| Record-triggered notification | Salesforce Flow | Platform Event or email alert, no API call |
| Simple one-system integration | Either (evaluate) | Both can handle it; choose by team skill |
| Multi-system orchestration | MuleSoft | Error handling, retry, timeout management |
| Batch data migration | MuleSoft | Bulk API, chunking, partial failure recovery |
| Real-time event streaming | MuleSoft | Backpressure, DLQ, subscriber scaling |
| UI-triggered callout | Salesforce Flow + MuleSoft API | Flow calls one MuleSoft endpoint |
| Scheduled data sync | MuleSoft | Scheduler, watermark, idempotent processing |
| Complex approval routing | Salesforce Flow | Native approval process, built-in UI |

## How It Works

1. **Score each criterion**: Rate your use case on a 1-5 scale for each of the seven criteria. A score of 1 means Salesforce Flow is the clear fit; 5 means MuleSoft is the clear fit.
2. **Calculate weighted score**: Multiply each score by its weight and sum the results. Data volume and external system count carry the highest weight (20% each) because they are the strongest predictors of tool fit.
3. **Interpret the result**: A weighted score below 2.0 strongly favors Salesforce Flow; above 3.0 strongly favors MuleSoft; between 2.0 and 3.0 requires a proof-of-concept with both tools.
4. **Check for anti-patterns**: Even after scoring, validate the design against known anti-patterns. A MuleSoft flow doing field validation or a Salesforce Flow making 5 HTTP callouts should be redesigned regardless of score.

## Key Takeaways

- The single most important criterion is the number of external systems. One or zero external systems almost always means Salesforce Flow; three or more almost always means MuleSoft.
- Never replicate Salesforce-native capabilities (validation rules, workflow rules, approval processes) in MuleSoft. It wastes API calls and creates maintenance burden.
- The 120-second timeout on Salesforce Flows is a hard constraint. Any process that might exceed it belongs in MuleSoft.
- When in doubt, use the "single callout" pattern: Salesforce Flow makes one HTTP callout to a MuleSoft API, which handles all external orchestration.
- Document your decision using this framework so future team members understand why the architecture was chosen.

## Related Recipes

- [Composite API Patterns](../composite-api-patterns/)
- [Governor Limit Safe Batch Processing](../governor-limit-safe-batch/)
- [SF Sync Loop Prevention](../sf-sync-loop-prevention/)
- [Agentforce Mule Action Registration](../agentforce-mule-action-registration/)
