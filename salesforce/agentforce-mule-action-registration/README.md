## Agentforce Mule Action Registration
> Register MuleSoft APIs as Agentforce actions using Connected Apps and External Services

### When to Use
- You want Agentforce agents to invoke MuleSoft APIs as part of their reasoning and action chain
- Your business logic lives in Mule and you need it accessible as an Agentforce action
- You are building an AI-assisted workflow that needs to query external systems, create records, or trigger processes via Mule
- You need to expose existing Mule APIs to Salesforce's agent framework without rewriting in Apex

### Configuration / Code

**Step 1: Create a Connected App in Salesforce**

Navigate to Setup > App Manager > New Connected App:
- **Connected App Name**: MuleSoft Integration Actions
- **API (Enable OAuth Settings)**: Checked
- **Callback URL**: `https://login.salesforce.com/services/oauth2/callback`
- **Selected OAuth Scopes**: `api`, `refresh_token`
- **Enable Client Credentials Flow**: Checked (for server-to-server)

Record the **Consumer Key** and **Consumer Secret**.

**Step 2: OpenAPI Spec for Action Definition**

```yaml
openapi: 3.0.3
info:
  title: Customer Order Lookup
  description: Retrieve order details for a given customer
  version: 1.0.0
servers:
  - url: https://your-mule-app.cloudhub.io/api
paths:
  /orders/{customerId}:
    get:
      operationId: getCustomerOrders
      summary: Get orders for a customer
      description: >
        Returns all orders for the specified customer including status,
        total amount, and line items. Use this when a customer asks about
        their order status or order history.
      parameters:
        - name: customerId
          in: path
          required: true
          description: The Salesforce Account ID or external customer ID
          schema:
            type: string
            example: "001xx000003DGbYAAW"
      responses:
        '200':
          description: List of customer orders
          content:
            application/json:
              schema:
                type: object
                properties:
                  customerId:
                    type: string
                    description: The customer identifier
                  orders:
                    type: array
                    items:
                      type: object
                      properties:
                        orderId:
                          type: string
                        status:
                          type: string
                          enum: [PENDING, PROCESSING, SHIPPED, DELIVERED, CANCELLED]
                        totalAmount:
                          type: number
                          format: double
                        orderDate:
                          type: string
                          format: date
                        lineItems:
                          type: array
                          items:
                            type: object
                            properties:
                              productName:
                                type: string
                              quantity:
                                type: integer
                              unitPrice:
                                type: number
                                format: double
        '404':
          description: Customer not found
```

**Step 3: Register External Service in Salesforce**

Navigate to Setup > External Services:
1. Click **New External Service**
2. **Service Name**: `CustomerOrderLookup`
3. **Service Schema**: Select "From API Specification" and paste the OpenAPI spec above
4. **Named Credential**: Select the Named Credential pointing to your Mule app (see below)
5. Click **Save & Next**, then **Finish**

**Named Credential Configuration**

Navigate to Setup > Named Credentials:
- **Label**: MuleSoft API Gateway
- **URL**: `https://your-mule-app.cloudhub.io`
- **Identity Type**: Named Principal
- **Authentication Protocol**: OAuth 2.0
- **Authentication Provider**: (Create one linked to your Connected App)
- **Scope**: `api`

**Step 4: Map to Agentforce Topic**

In Agentforce Setup:
1. Navigate to **Agent Topics**
2. Create or edit a topic (e.g., "Order Management")
3. Under **Actions**, click **Add Action**
4. Select **External Service Action** > `CustomerOrderLookup.getCustomerOrders`
5. Configure input mapping:
   - `customerId` -> Map from conversation context or entity extraction
6. Configure output instructions:
   - Tell the agent how to present the response to the user

**Step 5: Mule Flow Implementation**

```xml
<flow name="agentforce-order-lookup-flow">
    <http:listener config-ref="HTTPS_Listener_Config"
        path="/api/orders/{customerId}"
        allowedMethods="GET">
        <http:response statusCode="200">
            <http:headers>#[{
                'Content-Type': 'application/json',
                'X-Correlation-Id': correlationId
            }]</http:headers>
        </http:response>
        <http:error-response statusCode="#[vars.httpStatus default 500]">
            <http:headers>#[{
                'Content-Type': 'application/json'
            }]</http:headers>
        </http:error-response>
    </http:listener>

    <set-variable variableName="customerId"
        value="#[attributes.uriParams.customerId]"/>

    <!-- Validate input -->
    <choice>
        <when expression="#[vars.customerId == null or isEmpty(vars.customerId)]">
            <set-variable variableName="httpStatus" value="#[400]"/>
            <raise-error type="APP:BAD_REQUEST"
                description="customerId is required"/>
        </when>
    </choice>

    <!-- Query Salesforce for orders -->
    <salesforce:query config-ref="Salesforce_Config">
        <salesforce:salesforce-query>
            SELECT Id, OrderNumber, Status, TotalAmount, EffectiveDate,
                (SELECT Product2.Name, Quantity, UnitPrice FROM OrderItems)
            FROM Order
            WHERE AccountId = ':customerId'
            ORDER BY EffectiveDate DESC
            LIMIT 50
        </salesforce:salesforce-query>
        <salesforce:parameters>#[{
            customerId: vars.customerId
        }]</salesforce:parameters>
    </salesforce:query>

    <ee:transform>
        <ee:message>
            <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{
    customerId: vars.customerId,
    orders: payload map (order) -> {
        orderId: order.OrderNumber,
        status: order.Status,
        totalAmount: order.TotalAmount,
        orderDate: order.EffectiveDate as String { format: "yyyy-MM-dd" },
        lineItems: (order.OrderItems default []) map (item) -> {
            productName: item.Product2.Name,
            quantity: item.Quantity,
            unitPrice: item.UnitPrice
        }
    }
}
            ]]></ee:set-payload>
        </ee:message>
    </ee:transform>

    <error-handler>
        <on-error-propagate type="APP:BAD_REQUEST">
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{ error: "Bad Request", message: error.description }
                    ]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
        <on-error-propagate>
            <set-variable variableName="httpStatus" value="#[500]"/>
            <ee:transform>
                <ee:message>
                    <ee:set-payload><![CDATA[
%dw 2.0
output application/json
---
{ error: "Internal Server Error", message: "Unable to retrieve orders" }
                    ]]></ee:set-payload>
                </ee:message>
            </ee:transform>
        </on-error-propagate>
    </error-handler>
</flow>
```

### How It Works
1. Create a Connected App in Salesforce with OAuth 2.0 (Client Credentials flow) for server-to-server authentication
2. Write an OpenAPI 3.0 spec describing your Mule API's endpoints, parameters, and response schemas
3. Register the API as an External Service in Salesforce, which auto-generates Apex classes from the spec
4. Create a Named Credential pointing to your Mule runtime URL with the OAuth authentication
5. In Agentforce setup, add the External Service action to a Topic and configure input/output mappings
6. When a user interacts with the Agentforce agent, it determines whether to invoke the action based on the topic description and action summary
7. The agent calls the Mule API via the Named Credential, receives the JSON response, and formats it for the user

### Gotchas
- **Action timeout 60 seconds**: Agentforce actions must respond within 60 seconds. If your Mule flow involves slow downstream calls, implement async patterns with polling or callbacks
- **Response payload size limit**: Agentforce truncates large responses. Keep response payloads under 32 KB for reliable processing. Paginate large result sets
- **Required field mapping**: Every required parameter in your OpenAPI spec must be mappable from conversation context. If the agent cannot extract a required parameter, the action fails silently
- **OpenAPI spec quality matters**: The `description` fields in your OpenAPI spec directly influence when the agent decides to invoke the action. Write clear, intent-focused descriptions
- **Named Credential per environment**: You need separate Named Credentials for sandbox and production Mule endpoints. Use custom metadata types to switch at deployment time
- **Rate limiting**: Agentforce does not throttle action invocations by default. Add rate limiting on the Mule side (API Manager policy) to protect downstream systems

### Related
- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
- [Composite API Patterns](../composite-api-patterns/)
- [Governor Limit Safe Batch](../governor-limit-safe-batch/)
