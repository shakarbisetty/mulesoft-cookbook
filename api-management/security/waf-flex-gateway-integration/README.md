## WAF + Flex Gateway Integration
> Layer AWS WAF or Azure Front Door with Anypoint Flex Gateway for defense-in-depth API protection including rate limiting, geo-blocking, and injection filtering.

### When to Use
- APIs are exposed to the public internet and need DDoS and bot protection beyond what API Gateway provides
- Compliance requires a WAF layer (PCI-DSS, SOC 2)
- Need geo-blocking, IP reputation filtering, or managed rule sets for OWASP threats
- Deploying Flex Gateway behind a cloud load balancer with WAF capabilities

### Architecture

```
Internet
    |
    v
+-------------------+
|   AWS WAF /       |  Layer 1: DDoS, geo-blocking, IP reputation,
|   Azure Front Door|           managed rule sets (OWASP, Bot Control)
+-------------------+
    |
    v
+-------------------+
|   Load Balancer   |  Layer 2: SSL termination, health checks,
|   (ALB / AG)      |           traffic distribution
+-------------------+
    |
    v
+-------------------+
|   Flex Gateway    |  Layer 3: mTLS, JWT validation, rate limiting,
|                   |           API-specific policies, custom policies
+-------------------+
    |
    v
+-------------------+
|   Mule Runtime    |  Layer 4: Business logic, DataWeave transformation,
|                   |           parameterized queries, response filtering
+-------------------+
```

### Configuration / Code

#### AWS WAF Rule Group for API Protection

```json
{
  "Name": "mulesoft-api-protection",
  "Scope": "REGIONAL",
  "Description": "WAF rules for MuleSoft API protection",
  "Rules": [
    {
      "Name": "AWSManagedRulesCommonRuleSet",
      "Priority": 1,
      "OverrideAction": { "None": {} },
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesCommonRuleSet",
          "ExcludedRules": []
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "CommonRuleSet"
      }
    },
    {
      "Name": "AWSManagedRulesKnownBadInputsRuleSet",
      "Priority": 2,
      "OverrideAction": { "None": {} },
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesKnownBadInputsRuleSet"
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "KnownBadInputs"
      }
    },
    {
      "Name": "AWSManagedRulesSQLiRuleSet",
      "Priority": 3,
      "OverrideAction": { "None": {} },
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesSQLiRuleSet"
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "SQLiRuleSet"
      }
    },
    {
      "Name": "AWSManagedRulesBotControlRuleSet",
      "Priority": 4,
      "OverrideAction": { "None": {} },
      "Statement": {
        "ManagedRuleGroupStatement": {
          "VendorName": "AWS",
          "Name": "AWSManagedRulesBotControlRuleSet",
          "ManagedRuleGroupConfigs": [
            {
              "AWSManagedRulesBotControlRuleSet": {
                "InspectionLevel": "COMMON"
              }
            }
          ]
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "BotControl"
      }
    },
    {
      "Name": "RateLimitRule",
      "Priority": 5,
      "Action": { "Block": {} },
      "Statement": {
        "RateBasedStatement": {
          "Limit": 2000,
          "AggregateKeyType": "IP",
          "EvaluationWindowSec": 300
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "RateLimit"
      }
    },
    {
      "Name": "GeoBlockRule",
      "Priority": 6,
      "Action": { "Block": {} },
      "Statement": {
        "GeoMatchStatement": {
          "CountryCodes": ["KP", "IR", "SY", "CU"]
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "GeoBlock"
      }
    },
    {
      "Name": "PayloadSizeLimit",
      "Priority": 7,
      "Action": { "Block": {} },
      "Statement": {
        "SizeConstraintStatement": {
          "FieldToMatch": { "Body": {} },
          "ComparisonOperator": "GT",
          "Size": 1048576,
          "TextTransformations": [
            { "Priority": 0, "Type": "NONE" }
          ]
        }
      },
      "VisibilityConfig": {
        "SampledRequestsEnabled": true,
        "CloudWatchMetricsEnabled": true,
        "MetricName": "PayloadSize"
      }
    }
  ],
  "VisibilityConfig": {
    "SampledRequestsEnabled": true,
    "CloudWatchMetricsEnabled": true,
    "MetricName": "MuleSoftAPIProtection"
  }
}
```

#### AWS WAF — CloudFormation Snippet

```yaml
# cloudformation/waf-web-acl.yaml
AWSTemplateFormatVersion: '2010-09-09'
Description: WAF WebACL for MuleSoft API protection

Resources:
  MuleSoftAPIWebACL:
    Type: AWS::WAFv2::WebACL
    Properties:
      Name: mulesoft-api-waf
      Scope: REGIONAL
      DefaultAction:
        Allow: {}
      Rules:
        - Name: AWSManagedRulesCommonRuleSet
          Priority: 1
          OverrideAction:
            None: {}
          Statement:
            ManagedRuleGroupStatement:
              VendorName: AWS
              Name: AWSManagedRulesCommonRuleSet
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: CommonRules
        - Name: IPRateLimit
          Priority: 2
          Action:
            Block:
              CustomResponse:
                ResponseCode: 429
                ResponseHeaders:
                  - Name: Retry-After
                    Value: "60"
          Statement:
            RateBasedStatement:
              Limit: 2000
              AggregateKeyType: IP
          VisibilityConfig:
            SampledRequestsEnabled: true
            CloudWatchMetricsEnabled: true
            MetricName: IPRateLimit
      VisibilityConfig:
        SampledRequestsEnabled: true
        CloudWatchMetricsEnabled: true
        MetricName: MuleSoftWebACL

  # Associate WAF with ALB
  WAFAssociation:
    Type: AWS::WAFv2::WebACLAssociation
    Properties:
      ResourceArn: !Ref ALBArn  # Your Application Load Balancer ARN
      WebACLArn: !GetAtt MuleSoftAPIWebACL.Arn
```

#### Azure Front Door Configuration

```json
{
  "name": "mulesoft-api-frontdoor",
  "properties": {
    "frontendEndpoints": [
      {
        "name": "api-frontend",
        "properties": {
          "hostName": "api.example.com",
          "sessionAffinityEnabledState": "Disabled",
          "webApplicationFirewallPolicyLink": {
            "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Network/frontDoorWebApplicationFirewallPolicies/mulesoft-waf-policy"
          }
        }
      }
    ],
    "backendPools": [
      {
        "name": "flex-gateway-pool",
        "properties": {
          "backends": [
            {
              "address": "flex-gateway.eastus.cloudapp.azure.com",
              "httpPort": 80,
              "httpsPort": 443,
              "priority": 1,
              "weight": 100,
              "backendHostHeader": "flex-gateway.eastus.cloudapp.azure.com",
              "enabledState": "Enabled"
            },
            {
              "address": "flex-gateway.westus.cloudapp.azure.com",
              "httpPort": 80,
              "httpsPort": 443,
              "priority": 1,
              "weight": 100,
              "backendHostHeader": "flex-gateway.westus.cloudapp.azure.com",
              "enabledState": "Enabled"
            }
          ],
          "healthProbeSettings": {
            "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Network/frontDoors/mulesoft-api-frontdoor/healthProbeSettings/healthProbe"
          }
        }
      }
    ],
    "routingRules": [
      {
        "name": "api-routing",
        "properties": {
          "frontendEndpoints": [
            {
              "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Network/frontDoors/mulesoft-api-frontdoor/frontendEndpoints/api-frontend"
            }
          ],
          "acceptedProtocols": ["Https"],
          "patternsToMatch": ["/api/*"],
          "routeConfiguration": {
            "@odata.type": "#Microsoft.Azure.FrontDoor.Models.FrontdoorForwardingConfiguration",
            "forwardingProtocol": "HttpsOnly",
            "backendPool": {
              "id": "/subscriptions/{sub-id}/resourceGroups/{rg}/providers/Microsoft.Network/frontDoors/mulesoft-api-frontdoor/backendPools/flex-gateway-pool"
            }
          }
        }
      }
    ]
  }
}
```

#### Azure WAF Policy

```json
{
  "name": "mulesoft-waf-policy",
  "properties": {
    "policySettings": {
      "enabledState": "Enabled",
      "mode": "Prevention",
      "requestBodyCheck": "Enabled",
      "maxRequestBodySizeInKb": 1024
    },
    "managedRules": {
      "managedRuleSets": [
        {
          "ruleSetType": "Microsoft_DefaultRuleSet",
          "ruleSetVersion": "2.1",
          "ruleGroupOverrides": []
        },
        {
          "ruleSetType": "Microsoft_BotManagerRuleSet",
          "ruleSetVersion": "1.0"
        }
      ]
    },
    "customRules": {
      "rules": [
        {
          "name": "RateLimitByIP",
          "priority": 1,
          "ruleType": "RateLimitRule",
          "rateLimitDurationInMinutes": 5,
          "rateLimitThreshold": 1000,
          "matchConditions": [
            {
              "matchVariable": "RequestUri",
              "operator": "Contains",
              "matchValue": ["/api/"]
            }
          ],
          "action": "Block"
        },
        {
          "name": "GeoBlock",
          "priority": 2,
          "ruleType": "MatchRule",
          "matchConditions": [
            {
              "matchVariable": "RemoteAddr",
              "operator": "GeoMatch",
              "matchValue": ["KP", "IR", "SY", "CU"]
            }
          ],
          "action": "Block"
        }
      ]
    }
  }
}
```

#### Flex Gateway — Header Forwarding Configuration

Ensure WAF-injected headers are forwarded to Mule Runtime for logging and correlation.

```yaml
# flex-gateway/header-forwarding.yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: PolicyBinding
metadata:
  name: header-forwarding-policy
  namespace: production
spec:
  targetRef:
    kind: ApiInstance
    name: orders-api
  policyRef:
    name: header-injection
  config:
    # Forward WAF/CDN headers to upstream
    inboundHeaders:
      - name: X-Forwarded-For
        action: propagate
      - name: X-Azure-Ref
        action: propagate
      - name: X-Amzn-Trace-Id
        action: propagate
      - name: X-WAF-Action
        action: propagate
    # Remove internal headers from outbound responses
    outboundHeaders:
      - name: Server
        action: remove
      - name: X-Powered-By
        action: remove
      - name: X-AspNet-Version
        action: remove
```

### How It Works
1. **WAF layer** (AWS WAF / Azure Front Door) handles volumetric DDoS, bot detection, managed OWASP rule sets, geo-blocking, and IP reputation — operating at the edge before traffic reaches your infrastructure
2. **Load balancer** distributes traffic across Flex Gateway instances, handles SSL termination for the public-facing endpoint, and runs health checks
3. **Flex Gateway** applies API-specific policies: JWT validation, OAuth enforcement, mTLS, fine-grained rate limiting per client ID, and custom policies
4. **Mule Runtime** executes business logic with parameterized queries, response filtering, and input validation as the last line of defense
5. **Header forwarding** ensures correlation IDs and client IP information flow through all layers for end-to-end observability

### Gotchas
- **Rate limiting double-counting** — if both WAF (IP-based, 2000 req/5min) and Flex Gateway (client-ID-based, 100 req/min) enforce rate limits, a legitimate client behind a shared IP can be blocked at the WAF even though their per-client rate is under the Flex Gateway limit; coordinate thresholds so the WAF limit is higher than any single client's Flex Gateway limit
- **Header forwarding** — WAF/CDN layers add and modify headers (X-Forwarded-For, X-Real-IP); if Flex Gateway or Mule flows rely on `attributes.remoteAddress` for rate limiting, they may see the load balancer's IP instead of the client's; configure trusted proxy headers
- **WAF false positives** — managed rule sets (especially SQL injection rules) can block legitimate API payloads that contain SQL-like syntax in JSON values; test thoroughly and use rule exclusions for specific URIs
- **Cost** — AWS WAF charges per rule evaluation and per million requests; Azure Front Door Premium charges per policy; budget for WAF costs separately from Anypoint Platform licensing
- **TLS termination chain** — if the WAF terminates TLS and re-encrypts to the load balancer, which terminates and re-encrypts to Flex Gateway, you have three TLS sessions; ensure each hop uses TLS 1.2+ and valid certificates
- **Health check paths** — WAF health checks must reach Flex Gateway's health endpoint; exclude health check paths from authentication policies to avoid false-negative health checks
- **Logging correlation** — use a single trace ID (X-Amzn-Trace-Id or custom) across all layers; configure WAF, load balancer, Flex Gateway, and Mule Runtime to log the same trace ID

### Related
- [Zero Trust with Flex Gateway](../zero-trust-flex-gateway/)
- [mTLS Client Certificate](../mtls-client-cert/)
- [OWASP API Top 10 Mapping](../owasp-api-top10-mapping/)
- [Security Scanning in CI/CD](../security-scanning-cicd/)
- [CORS Configuration](../cors-config/)
