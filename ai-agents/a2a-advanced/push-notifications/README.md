## A2A Push Notifications
> Receive asynchronous task completion notifications from remote agents.

### When to Use
- Long-running agent tasks where polling is inefficient
- Event-driven architectures where agents notify on completion
- Webhook-based integration with external AI services

### Configuration / Code

```xml
<!-- Register notification webhook -->
<flow name="a2a-task-with-notification">
    <http:listener config-ref="HTTP_Listener" path="/start-task" method="POST"/>
    <http:request config-ref="Remote_Agent" path="/a2a/tasks/send" method="POST">
        <http:body>#[output application/json --- {
            jsonrpc: "2.0", method: "tasks/send",
            params: {
                task: {message: {role: "user", parts: [{type: "text", text: payload.prompt}]}},
                pushNotification: {url: "https://myserver.com/a2a/notifications", token: vars.authToken}
            }
        }]</http:body>
    </http:request>
</flow>

<!-- Receive completion notification -->
<flow name="a2a-notification-receiver">
    <http:listener config-ref="HTTP_Listener" path="/a2a/notifications" method="POST"/>
    <logger message="Task #[payload.params.taskId] completed: #[payload.params.status]"/>
    <flow-ref name="process-agent-result"/>
</flow>
```

### How It Works
1. Task request includes a `pushNotification` URL
2. Remote agent processes the task asynchronously
3. On completion, agent sends a POST to the notification URL
4. Receiver processes the result without polling

### Gotchas
- Notification URL must be publicly reachable by the remote agent
- Implement HMAC signature verification on incoming notifications
- Notifications can be lost — implement a polling fallback
- Idempotency: the same notification may arrive multiple times

### Related
- [Streaming Artifacts](../streaming-artifacts/) — real-time streaming
- [Multi-Agent Orchestration](../multi-agent-orchestration/) — workflow coordination
