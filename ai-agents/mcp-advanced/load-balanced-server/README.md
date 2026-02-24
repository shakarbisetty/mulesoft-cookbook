## Load-Balanced MCP Server
> Deploy MCP servers behind a load balancer for high availability and scalability.

### When to Use
- Production MCP deployments serving multiple AI agents
- High-throughput tool execution requiring horizontal scaling
- Zero-downtime deployments and rolling updates

### Configuration / Code

```yaml
# Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mcp-server
spec:
  replicas: 3
  selector:
    matchLabels:
      app: mcp-server
  template:
    spec:
      containers:
      - name: mule-mcp
        image: mcp-server:1.0
        ports:
        - containerPort: 8081
        readinessProbe:
          httpGet:
            path: /mcp/health
            port: 8081
          initialDelaySeconds: 30
---
apiVersion: v1
kind: Service
metadata:
  name: mcp-server
spec:
  type: ClusterIP
  selector:
    app: mcp-server
  ports:
  - port: 443
    targetPort: 8081
```

### How It Works
1. Multiple MCP server replicas run behind a Kubernetes Service
2. Load balancer distributes requests across healthy replicas
3. Readiness probes ensure traffic only goes to ready instances
4. Horizontal scaling handles increased AI agent demand

### Gotchas
- Stateful tools (in-memory context) need sticky sessions or external state
- SSE/streaming connections require connection-aware load balancing
- Health check endpoint must verify downstream dependencies
- Rolling updates should use maxUnavailable=0 for zero downtime

### Related
- [OAuth Security](../oauth-security/) — securing the endpoint
- [Distributed Tracing](../distributed-tracing/) — tracing across replicas
