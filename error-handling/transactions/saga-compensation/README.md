## SAGA Pattern with Compensating Transactions
> Orchestrate multi-service operations where each step has a compensation flow for undo.

### When to Use
- Distributed transactions across multiple services (payment + inventory + shipping)
- XA transactions are not possible (different systems, HTTP-based services)
- Each step can be individually reversed with a compensation action

### Configuration / Code

```xml
<flow name="order-saga-flow">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST"/>
    <set-variable variableName="sagaState" value="#[{steps: []}]"/>

    <!-- Step 1: Reserve inventory -->
    <try>
        <http:request config-ref="Inventory_Service" path="/reserve" method="POST"/>
        <set-variable variableName="sagaState" value="#[vars.sagaState ++ {steps: vars.sagaState.steps ++ ['inventory']}]"/>

        <!-- Step 2: Charge payment -->
        <try>
            <http:request config-ref="Payment_Service" path="/charge" method="POST"/>
            <set-variable variableName="sagaState" value="#[vars.sagaState ++ {steps: vars.sagaState.steps ++ ['payment']}]"/>

            <!-- Step 3: Create shipment -->
            <http:request config-ref="Shipping_Service" path="/ship" method="POST"/>

            <error-handler>
                <on-error-propagate type="ANY">
                    <logger level="ERROR" message="Shipping failed, compensating payment and inventory"/>
                    <!-- Compensate Step 2 -->
                    <http:request config-ref="Payment_Service" path="/refund" method="POST"/>
                    <!-- Compensate Step 1 -->
                    <http:request config-ref="Inventory_Service" path="/release" method="POST"/>
                </on-error-propagate>
            </error-handler>
        </try>

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR" message="Payment failed, compensating inventory"/>
                <!-- Compensate Step 1 only -->
                <http:request config-ref="Inventory_Service" path="/release" method="POST"/>
            </on-error-propagate>
        </error-handler>
    </try>

    <error-handler>
        <on-error-propagate type="ANY">
            <set-variable variableName="httpStatus" value="500"/>
            <set-payload value='{"error":"Order failed, all steps compensated"}' mimeType="application/json"/>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. Each step is wrapped in a nested try scope
2. On failure, the error handler calls compensation APIs for all completed steps
3. Compensation runs in reverse order (last completed → first completed)
4. `sagaState` tracks which steps have been completed

### Gotchas
- Compensation actions can also fail — you may need retry logic within compensation flows
- This provides eventual consistency, not ACID — there is a window of inconsistency
- Idempotent compensation is critical — calling refund twice should not double-refund
- Consider storing saga state in Object Store for recovery if the app crashes mid-saga

### Related
- [XA Transaction Rollback](../xa-transaction-rollback/) — ACID alternative for supported resources
- [Fallback Service Routing](../../recovery/fallback-service-routing/) — simpler fallback pattern
