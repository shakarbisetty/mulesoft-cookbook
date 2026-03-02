## EDA Saga Orchestration Pattern

> Implement the saga pattern with compensating actions across 3+ services to achieve distributed transaction consistency without XA.

### When to Use
- You have a business transaction spanning multiple services (order + payment + inventory + shipping) that must be atomic
- XA/2PC is not possible because some participants are HTTP APIs, SaaS systems, or external services
- You need to automatically undo partial work when a step fails mid-transaction
- Compliance requires an audit trail of every action and compensation

### The Problem
A multi-service business operation (e.g., "place order") involves calling multiple systems that cannot participate in a single ACID transaction. If service 3 of 5 fails, services 1 and 2 have already committed their changes. Without a saga, you have inconsistent data across systems -- inventory reserved but no order created, or payment charged but shipment not scheduled. The saga pattern solves this by defining a compensating action for each step: if step N fails, execute compensations for steps N-1 through 1 in reverse order.

### Configuration

#### Saga Orchestrator Flow

```xml
<!--
    Saga: Place Order
    Steps:
    1. Reserve inventory   → Compensate: Release inventory
    2. Charge payment      → Compensate: Refund payment
    3. Create shipment     → Compensate: Cancel shipment
    4. Confirm order       → Compensate: Cancel order

    The orchestrator manages step execution and compensation.
-->

<!-- Object Store for saga state persistence -->
<os:object-store name="saga-state-store"
    persistent="true"
    entryTtl="24"
    entryTtlUnit="HOURS" />

<flow name="saga-place-order">
    <http:listener config-ref="HTTP_Listener" path="/api/orders" method="POST" />

    <!-- Initialize saga state -->
    <set-variable variableName="sagaId" value="#[uuid()]" />
    <set-variable variableName="completedSteps" value="#[[]]" />

    <os:store objectStore="saga-state-store" key="#[vars.sagaId]">
        <os:value><![CDATA[#[output application/json --- {
            sagaId: vars.sagaId,
            status: "STARTED",
            startedAt: now(),
            order: payload,
            completedSteps: [],
            compensatedSteps: []
        }]]]></os:value>
    </os:store>

    <logger level="INFO" message="Saga #[vars.sagaId] started for order #[payload.orderId]" />

    <try>
        <!-- Step 1: Reserve Inventory -->
        <flow-ref name="saga-step-reserve-inventory" />

        <!-- Step 2: Charge Payment -->
        <flow-ref name="saga-step-charge-payment" />

        <!-- Step 3: Create Shipment -->
        <flow-ref name="saga-step-create-shipment" />

        <!-- Step 4: Confirm Order -->
        <flow-ref name="saga-step-confirm-order" />

        <!-- All steps succeeded -->
        <os:store objectStore="saga-state-store" key="#[vars.sagaId]">
            <os:value><![CDATA[#[output application/json --- {
                sagaId: vars.sagaId,
                status: "COMPLETED",
                completedAt: now(),
                completedSteps: vars.completedSteps
            }]]]></os:value>
        </os:store>

        <ee:transform>
            <ee:message>
                <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    sagaId: vars.sagaId,
    status: "COMPLETED",
    orderId: vars.orderId
}]]></ee:set-payload>
            </ee:message>
        </ee:transform>

        <error-handler>
            <on-error-propagate type="ANY">
                <logger level="ERROR"
                    message="Saga #[vars.sagaId] failed at step — initiating compensation: #[error.description]" />

                <!-- Execute compensating actions in reverse order -->
                <flow-ref name="saga-compensate" />

                <os:store objectStore="saga-state-store" key="#[vars.sagaId]">
                    <os:value><![CDATA[#[output application/json --- {
                        sagaId: vars.sagaId,
                        status: "COMPENSATED",
                        failedAt: now(),
                        error: error.description,
                        completedSteps: vars.completedSteps,
                        compensatedSteps: vars.compensatedSteps default []
                    }]]]></os:value>
                </os:store>

                <ee:transform>
                    <ee:message>
                        <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
{
    sagaId: vars.sagaId,
    status: "FAILED_COMPENSATED",
    error: error.description
}]]></ee:set-payload>
                    </ee:message>
                </ee:transform>

                <set-variable variableName="httpStatus" value="409" />
            </on-error-propagate>
        </error-handler>
    </try>
</flow>
```

#### Saga Steps (Forward Actions)

```xml
<!-- Step 1: Reserve Inventory -->
<sub-flow name="saga-step-reserve-inventory">
    <http:request config-ref="Inventory_API" method="POST"
        path="/api/inventory/reserve"
        responseTimeout="10000">
        <http:body><![CDATA[#[output application/json --- {
            orderId: payload.orderId,
            items: payload.items
        }]]]></http:body>
    </http:request>

    <set-variable variableName="reservationId" value="#[payload.reservationId]" />
    <set-variable variableName="completedSteps"
        value="#[vars.completedSteps ++ [{step: 'RESERVE_INVENTORY', reservationId: vars.reservationId}]]" />

    <logger level="INFO" message="Saga #[vars.sagaId] Step 1 DONE: inventory reserved (#[vars.reservationId])" />
</sub-flow>

<!-- Step 2: Charge Payment -->
<sub-flow name="saga-step-charge-payment">
    <http:request config-ref="Payment_API" method="POST"
        path="/api/payments/charge"
        responseTimeout="15000">
        <http:body><![CDATA[#[output application/json --- {
            orderId: payload.orderId,
            amount: payload.totalAmount,
            currency: payload.currency,
            paymentMethod: payload.paymentMethodId
        }]]]></http:body>
    </http:request>

    <set-variable variableName="paymentId" value="#[payload.paymentId]" />
    <set-variable variableName="completedSteps"
        value="#[vars.completedSteps ++ [{step: 'CHARGE_PAYMENT', paymentId: vars.paymentId}]]" />

    <logger level="INFO" message="Saga #[vars.sagaId] Step 2 DONE: payment charged (#[vars.paymentId])" />
</sub-flow>

<!-- Step 3: Create Shipment -->
<sub-flow name="saga-step-create-shipment">
    <http:request config-ref="Shipping_API" method="POST"
        path="/api/shipments"
        responseTimeout="10000">
        <http:body><![CDATA[#[output application/json --- {
            orderId: payload.orderId,
            address: payload.shippingAddress,
            items: payload.items
        }]]]></http:body>
    </http:request>

    <set-variable variableName="shipmentId" value="#[payload.shipmentId]" />
    <set-variable variableName="completedSteps"
        value="#[vars.completedSteps ++ [{step: 'CREATE_SHIPMENT', shipmentId: vars.shipmentId}]]" />

    <logger level="INFO" message="Saga #[vars.sagaId] Step 3 DONE: shipment created (#[vars.shipmentId])" />
</sub-flow>

<!-- Step 4: Confirm Order -->
<sub-flow name="saga-step-confirm-order">
    <http:request config-ref="Order_API" method="PUT"
        path="#['/api/orders/' ++ payload.orderId ++ '/confirm']"
        responseTimeout="10000">
        <http:body><![CDATA[#[output application/json --- {
            reservationId: vars.reservationId,
            paymentId: vars.paymentId,
            shipmentId: vars.shipmentId
        }]]]></http:body>
    </http:request>

    <set-variable variableName="orderId" value="#[payload.orderId]" />
    <set-variable variableName="completedSteps"
        value="#[vars.completedSteps ++ [{step: 'CONFIRM_ORDER', orderId: vars.orderId}]]" />

    <logger level="INFO" message="Saga #[vars.sagaId] Step 4 DONE: order confirmed (#[vars.orderId])" />
</sub-flow>
```

#### Compensating Actions (Reverse Order)

```xml
<!-- Compensation orchestrator: reverse through completed steps -->
<sub-flow name="saga-compensate">
    <set-variable variableName="compensatedSteps" value="#[[]]" />

    <!-- Reverse iterate through completed steps -->
    <foreach collection="#[vars.completedSteps[-1 to 0]]">
        <logger level="WARN"
            message="Saga #[vars.sagaId] compensating: #[payload.step]" />

        <choice>
            <when expression="#[payload.step == 'CONFIRM_ORDER']">
                <try>
                    <http:request config-ref="Order_API" method="PUT"
                        path="#['/api/orders/' ++ payload.orderId ++ '/cancel']">
                        <http:body><![CDATA[#[output application/json --- {reason: "Saga compensation"}]]]></http:body>
                    </http:request>
                    <set-variable variableName="compensatedSteps"
                        value="#[vars.compensatedSteps ++ [{step: 'CANCEL_ORDER', status: 'SUCCESS'}]]" />
                    <error-handler>
                        <on-error-continue type="ANY">
                            <logger level="ERROR"
                                message="COMPENSATION FAILED: cancel order — #[error.description]" />
                            <set-variable variableName="compensatedSteps"
                                value="#[vars.compensatedSteps ++ [{step: 'CANCEL_ORDER', status: 'FAILED', error: error.description}]]" />
                        </on-error-continue>
                    </error-handler>
                </try>
            </when>

            <when expression="#[payload.step == 'CREATE_SHIPMENT']">
                <try>
                    <http:request config-ref="Shipping_API" method="DELETE"
                        path="#['/api/shipments/' ++ payload.shipmentId]" />
                    <set-variable variableName="compensatedSteps"
                        value="#[vars.compensatedSteps ++ [{step: 'CANCEL_SHIPMENT', status: 'SUCCESS'}]]" />
                    <error-handler>
                        <on-error-continue type="ANY">
                            <logger level="ERROR"
                                message="COMPENSATION FAILED: cancel shipment — #[error.description]" />
                            <set-variable variableName="compensatedSteps"
                                value="#[vars.compensatedSteps ++ [{step: 'CANCEL_SHIPMENT', status: 'FAILED', error: error.description}]]" />
                        </on-error-continue>
                    </error-handler>
                </try>
            </when>

            <when expression="#[payload.step == 'CHARGE_PAYMENT']">
                <try>
                    <http:request config-ref="Payment_API" method="POST"
                        path="#['/api/payments/' ++ payload.paymentId ++ '/refund']">
                        <http:body><![CDATA[#[output application/json --- {reason: "Saga compensation"}]]]></http:body>
                    </http:request>
                    <set-variable variableName="compensatedSteps"
                        value="#[vars.compensatedSteps ++ [{step: 'REFUND_PAYMENT', status: 'SUCCESS'}]]" />
                    <error-handler>
                        <on-error-continue type="ANY">
                            <logger level="ERROR"
                                message="COMPENSATION FAILED: refund payment — #[error.description]" />
                            <set-variable variableName="compensatedSteps"
                                value="#[vars.compensatedSteps ++ [{step: 'REFUND_PAYMENT', status: 'FAILED', error: error.description}]]" />
                        </on-error-continue>
                    </error-handler>
                </try>
            </when>

            <when expression="#[payload.step == 'RESERVE_INVENTORY']">
                <try>
                    <http:request config-ref="Inventory_API" method="DELETE"
                        path="#['/api/inventory/reserve/' ++ payload.reservationId]" />
                    <set-variable variableName="compensatedSteps"
                        value="#[vars.compensatedSteps ++ [{step: 'RELEASE_INVENTORY', status: 'SUCCESS'}]]" />
                    <error-handler>
                        <on-error-continue type="ANY">
                            <logger level="ERROR"
                                message="COMPENSATION FAILED: release inventory — #[error.description]" />
                            <set-variable variableName="compensatedSteps"
                                value="#[vars.compensatedSteps ++ [{step: 'RELEASE_INVENTORY', status: 'FAILED', error: error.description}]]" />
                        </on-error-continue>
                    </error-handler>
                </try>
            </when>
        </choice>
    </foreach>
</sub-flow>
```

#### Saga Status Query Endpoint

```xml
<flow name="saga-status">
    <http:listener config-ref="HTTP_Listener" path="/api/sagas/{sagaId}" method="GET" />

    <os:retrieve objectStore="saga-state-store"
        key="#[attributes.uriParams.sagaId]" target="sagaState" />

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[%dw 2.0
output application/json
---
read(vars.sagaState, "application/json")]]></ee:set-payload>
        </ee:message>
    </ee:transform>
</flow>
```

### Saga State Machine

```
                    ┌──────────┐
                    │ STARTED  │
                    └────┬─────┘
                         │
            ┌────────────┼────────────┐
            │            │            │
       Step 1 OK    Step 1 OK    Step 1 FAIL
       Step 2 OK    Step 2 FAIL       │
       Step 3 OK         │            ▼
       Step 4 OK         ▼      ┌──────────────┐
            │      ┌──────────┐ │ COMPENSATING │
            ▼      │COMPENSATE│ └──────┬───────┘
     ┌──────────┐  │ING      │        │
     │COMPLETED │  └────┬────┘    Compensate
     └──────────┘       │        Step 1
                        │            │
                   Compensate        ▼
                   Step 2 → 1  ┌──────────────┐
                        │      │ COMPENSATED  │
                        ▼      └──────────────┘
                  ┌──────────────┐
                  │ COMPENSATED  │
                  └──────────────┘
                        │
                  If compensation
                  fails:
                        ▼
                  ┌──────────────┐
                  │   FAILED     │ ← requires manual intervention
                  └──────────────┘
```

### Gotchas
- **Compensation can fail too**: If the refund API is down when you try to compensate, you have a partially compensated saga. Always wrap each compensation in a try/catch, log failures, and implement a scheduled job to retry failed compensations.
- **Idempotent compensations are mandatory**: A compensation may be retried (e.g., after a timeout where the action actually succeeded). Every compensation must be idempotent -- calling "refund payment X" twice should not issue two refunds.
- **Saga state must be persistent**: If the orchestrator crashes mid-saga, you need to resume compensation on restart. Store saga state in Object Store or database, not in-memory variables. The flow above uses Object Store.
- **Long-running sagas and timeouts**: If Step 3 takes 5 minutes (waiting for a manual approval), the HTTP listener times out. For long-running sagas, return a 202 Accepted with the sagaId and let the client poll for status.
- **Ordering matters in compensation**: Compensate in reverse order (last step first). If you release inventory before refunding payment, there is a window where another customer could reserve the same inventory, then you fail to release it during the refund step.
- **Semantic compensation vs exact undo**: A "refund" is not an exact undo of a "charge." The refund may take 3-5 business days, appear as a separate line item, and have different tax implications. Design compensations for business correctness, not technical symmetry.
- **Saga per aggregate, not per entity**: Run one saga per business transaction (e.g., one order), not per item within the order. If an order has 5 items, do not run 5 sagas -- that creates coordination complexity.

### Testing

```xml
<munit:test name="test-saga-compensation-on-payment-failure"
    description="Verify inventory is released when payment fails">

    <munit:behavior>
        <!-- Inventory succeeds -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="config-ref" whereValue="Inventory_API" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:payload value='#[{reservationId: "RES-001"}]' />
            </munit-tools:then-return>
        </munit-tools:mock-when>

        <!-- Payment fails -->
        <munit-tools:mock-when processor="http:request">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="config-ref" whereValue="Payment_API" />
            </munit-tools:with-attributes>
            <munit-tools:then-return>
                <munit-tools:error typeId="HTTP:SERVICE_UNAVAILABLE" />
            </munit-tools:then-return>
        </munit-tools:mock-when>
    </munit:behavior>

    <munit:execution>
        <set-payload value='#[output application/json --- {
            orderId: "ORD-001",
            items: [{sku: "SKU-A", qty: 2}],
            totalAmount: 99.99,
            currency: "USD"
        }]' />
        <flow-ref name="saga-place-order" />
    </munit:execution>

    <munit:validation>
        <!-- Verify inventory release (compensation) was called -->
        <munit-tools:verify-call processor="http:request" times="1">
            <munit-tools:with-attributes>
                <munit-tools:with-attribute attributeName="method" whereValue="DELETE" />
            </munit-tools:with-attributes>
        </munit-tools:verify-call>
    </munit:validation>
</munit:test>
```

### Related Recipes
- [EDA Event Sourcing](../eda-event-sourcing-mulesoft/) -- event sourcing as an alternative to saga state tracking
- [JMS XA Transaction Patterns](../jms-xa-transaction-patterns/) -- when XA is possible and preferred over saga
- [Anypoint MQ DLQ Reprocessing](../anypoint-mq-dlq-reprocessing/) -- handling saga messages that fail delivery
