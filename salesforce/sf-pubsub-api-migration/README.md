# Salesforce Pub/Sub API Migration Guide

## Problem

Salesforce is deprecating the legacy CometD-based Streaming API in favor of the new gRPC-based Pub/Sub API. Existing MuleSoft integrations that rely on PushTopics, Generic Streaming, or the Bayeux protocol must be migrated before the deprecation deadline. The new API has fundamentally different authentication, subscription management, replay ID handling, and error semantics. A poorly planned migration causes event loss during the cutover window and breaks replay continuity.

## Solution

Provide a side-by-side comparison of old and new configurations, a step-by-step migration checklist, and a parallel-run strategy that operates both subscribers simultaneously during the transition period. Cover authentication changes, replay ID format differences, and performance improvements that come with the gRPC transport.

## Implementation

**Old Configuration: CometD / Streaming API Connector**

```xml
<!-- LEGACY: CometD-based Streaming API subscription -->
<salesforce:subscribe-topic config-ref="Salesforce_Config_Legacy"
                            topic="/topic/AccountChanges"
                            replayOption="LATEST"/>

<!-- Legacy connector config -->
<salesforce:sfdc-config name="Salesforce_Config_Legacy">
    <salesforce:basic-connection
        username="${sf.username}"
        password="${sf.password}"
        securityToken="${sf.securityToken}"
        url="https://login.salesforce.com"/>
</salesforce:sfdc-config>
```

**New Configuration: Pub/Sub API (gRPC)**

```xml
<!-- NEW: gRPC-based Pub/Sub API subscription -->
<salesforce:subscribe-channel config-ref="Salesforce_Config_PubSub"
                               channelName="/data/AccountChangeEvent"
                               replayPreset="LATEST">
    <salesforce:replay-id>#[vars.storedReplayId]</salesforce:replay-id>
</salesforce:subscribe-channel>

<!-- New connector config with OAuth 2.0 Client Credentials -->
<salesforce:sfdc-config name="Salesforce_Config_PubSub">
    <salesforce:oauth-client-credentials-connection
        consumerKey="${sf.connected.app.clientId}"
        consumerSecret="${sf.connected.app.clientSecret}"
        tokenUrl="https://login.salesforce.com/services/oauth2/token"
        audienceUrl="https://login.salesforce.com"/>
</salesforce:sfdc-config>
```

**Migration Comparison Table**

| Feature | CometD / Streaming API | Pub/Sub API (gRPC) |
|---|---|---|
| Protocol | HTTP long-polling (Bayeux) | gRPC (HTTP/2 bidirectional streaming) |
| Authentication | Username + Password + Security Token | OAuth 2.0 (Client Credentials or JWT Bearer) |
| Subscription target | PushTopic name, Generic Event | Channel name (CDC, Platform Event, Custom Channel) |
| Replay ID format | Numeric (sequential) | Byte string (opaque) |
| Replay retention | 24 hours | 72 hours (configurable) |
| Max events per request | 1 (long-poll per event) | Configurable batch (up to 100) |
| Throughput | ~1,000 events/min | ~20,000 events/min |
| Backpressure | None (drop or disconnect) | Flow control via `fetchRequest` |
| PushTopics | Supported | Not supported (use CDC instead) |

**Parallel-Run Migration Flow**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<mule xmlns:ee="http://www.mulesoft.org/schema/mule/ee/core"
      xmlns:salesforce="http://www.mulesoft.org/schema/mule/salesforce"
      xmlns:os="http://www.mulesoft.org/schema/mule/os"
      xmlns="http://www.mulesoft.org/schema/mule/core"
      xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
      xsi:schemaLocation="http://www.mulesoft.org/schema/mule/core
        http://www.mulesoft.org/schema/mule/core/current/mule.xsd">

    <!-- Replay ID storage -->
    <os:object-store name="replayIdStore"
                     persistent="true"
                     entryTtl="96"
                     entryTtlUnit="HOURS"/>

    <!-- Feature flag: controls which subscriber is active -->
    <global-property name="migration.mode" value="PARALLEL"/>
    <!-- Values: LEGACY_ONLY, PARALLEL, PUBSUB_ONLY -->

    <!-- LEGACY subscriber (disable when migration complete) -->
    <flow name="legacy-cometd-subscriber"
          initialState="#[if (Mule::p('migration.mode') != 'PUBSUB_ONLY') 'started' else 'stopped']">
        <salesforce:subscribe-topic config-ref="Salesforce_Config_Legacy"
                                    topic="/topic/AccountChanges"
                                    replayOption="LATEST"/>

        <set-variable variableName="eventSource" value="COMETD"/>
        <set-variable variableName="eventKey"
                      value="#[payload.Id ++ '-' ++ payload.SystemModstamp]"/>

        <flow-ref name="deduplicated-event-processor"/>
    </flow>

    <!-- NEW Pub/Sub API subscriber -->
    <flow name="pubsub-grpc-subscriber"
          initialState="#[if (Mule::p('migration.mode') != 'LEGACY_ONLY') 'started' else 'stopped']">

        <!-- Retrieve last stored replay ID -->
        <os:retrieve key="pubsub-replay-id"
                     objectStore="replayIdStore"
                     target="storedReplayId">
            <os:default-value>#[null]</os:default-value>
        </os:retrieve>

        <salesforce:subscribe-channel config-ref="Salesforce_Config_PubSub"
                                      channelName="/data/AccountChangeEvent"
                                      replayPreset="#[if (vars.storedReplayId != null) 'CUSTOM' else 'LATEST']">
            <salesforce:replay-id>#[vars.storedReplayId]</salesforce:replay-id>
        </salesforce:subscribe-channel>

        <!-- Persist replay ID after each event -->
        <os:store key="pubsub-replay-id"
                  objectStore="replayIdStore">
            <os:value>#[attributes.replayId]</os:value>
        </os:store>

        <set-variable variableName="eventSource" value="PUBSUB"/>
        <set-variable variableName="eventKey"
                      value="#[payload.ChangeEventHeader.recordIds[0] ++ '-'
                              ++ payload.ChangeEventHeader.commitTimestamp]"/>

        <flow-ref name="deduplicated-event-processor"/>
    </flow>

    <!-- Deduplication layer for parallel-run mode -->
    <sub-flow name="deduplicated-event-processor">
        <!-- In PARALLEL mode, both subscribers receive the same events.
             Use a dedup key to process each event exactly once. -->
        <os:retrieve key="#['dedup-' ++ vars.eventKey]"
                     objectStore="replayIdStore"
                     target="alreadyProcessed">
            <os:default-value>#[false]</os:default-value>
        </os:retrieve>

        <choice>
            <when expression="#[vars.alreadyProcessed == false]">
                <!-- Mark as processing -->
                <os:store key="#['dedup-' ++ vars.eventKey]"
                          objectStore="replayIdStore">
                    <os:value>#[true]</os:value>
                </os:store>

                <logger level="INFO"
                        message='Processing event from #[vars.eventSource]: #[vars.eventKey]'/>

                <!-- Route to business logic -->
                <flow-ref name="process-account-change"/>
            </when>
            <otherwise>
                <logger level="DEBUG"
                        message='Skipping duplicate event from #[vars.eventSource]: #[vars.eventKey]'/>
            </otherwise>
        </choice>
    </sub-flow>
</mule>
```

**Migration Checklist**

```yaml
migration_checklist:
  pre_migration:
    - task: "Inventory all PushTopics and replace with CDC or Platform Events"
      notes: "Pub/Sub API does not support PushTopics. Create equivalent CDC channels."
    - task: "Upgrade Salesforce Connector to 10.18+ (Pub/Sub API support)"
    - task: "Switch authentication from username/password to OAuth 2.0 Client Credentials"
    - task: "Create Connected App in Salesforce with required OAuth scopes"
    - task: "Update firewall rules: gRPC uses port 443 with HTTP/2 (same as HTTPS)"
    - task: "Verify Mule runtime is 4.4.0+ (gRPC transport support)"

  migration_steps:
    - step: 1
      action: "Deploy Pub/Sub subscriber in PARALLEL mode alongside legacy subscriber"
    - step: 2
      action: "Run both subscribers for 48-72 hours, monitoring dedup hit rate"
    - step: 3
      action: "Verify event counts match between legacy and Pub/Sub subscriber logs"
    - step: 4
      action: "Switch migration.mode to PUBSUB_ONLY"
    - step: 5
      action: "Monitor for 24 hours, verify no event loss"
    - step: 6
      action: "Remove legacy subscriber flow and CometD connector dependency"

  post_migration:
    - task: "Delete PushTopics from Salesforce org"
    - task: "Remove security token from Mule properties (no longer needed with OAuth)"
    - task: "Update monitoring dashboards to track gRPC metrics"
    - task: "Document new replay ID format (opaque bytes, not numeric)"
```

## How It Works

1. **Parallel deployment**: Both the legacy CometD subscriber and the new Pub/Sub API subscriber run simultaneously, controlled by a `migration.mode` property.
2. **Deduplication**: Since both subscribers receive the same events, a dedup layer using an Object Store prevents double-processing. The dedup key combines the record ID and timestamp.
3. **Replay ID migration**: The new subscriber manages its own replay ID persistence using the Pub/Sub API's opaque byte format, independent of the legacy numeric replay IDs.
4. **Phased cutover**: After validating event parity in parallel mode (48-72 hours), the legacy subscriber is disabled by switching the property to `PUBSUB_ONLY`.
5. **Cleanup**: Once stable, the legacy subscriber flow and CometD connector are removed entirely.

## Key Takeaways

- PushTopics are not available in the Pub/Sub API. Replace them with Change Data Capture channels before migrating.
- Pub/Sub API replay IDs are opaque byte strings, not sequential numbers. Do not attempt to compare them numerically or convert between formats.
- The gRPC transport supports batched event fetch (up to 100 events per request), providing 10-20x higher throughput than CometD long-polling.
- Always run a parallel period with deduplication to validate event parity before cutting over. Missing events during migration is the top post-migration issue.
- OAuth 2.0 Client Credentials is the recommended authentication for server-to-server integrations. Remove username/password/security token patterns.

## Related Recipes

- [Streaming API Integration](../salesforce-streaming-api/)
- [High-Volume Platform Events](../high-volume-platform-events/)
- [CDC vs Platform Events Decision Guide](../cdc-vs-platform-events-decision/)
- [Connected App OAuth Patterns](../connected-app-oauth-patterns/)
