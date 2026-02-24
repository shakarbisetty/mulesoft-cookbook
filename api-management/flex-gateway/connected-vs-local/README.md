## Connected vs Local Mode
> Choose between Connected mode (API Manager control) and Local mode (declarative YAML).

### When to Use
- **Connected**: production environments with centralized API governance
- **Local**: air-gapped environments, CI/CD-driven config, edge deployments

### Configuration / Code

**Connected mode** — managed via API Manager UI:
```bash
flexctl register my-gw --connected=true --token=$TOKEN --organization=$ORG_ID
```

**Local mode** — declarative YAML config:
```yaml
apiVersion: gateway.mulesoft.com/v1alpha1
kind: ApiInstance
metadata:
  name: orders-api
spec:
  address: http://0.0.0.0:8081
  services:
    orders:
      address: http://orders-backend:8080
      routes:
        - rules:
          - path: /api/orders(/.*)?
          config:
            destinationPath: /orders
```

### How It Works
1. **Connected**: Gateway polls API Manager for config changes; policies managed in UI
2. **Local**: Gateway reads YAML files from a config directory; changes require file updates
3. Both modes support the same policies and routing capabilities
4. Local mode can be version-controlled and deployed via CI/CD

### Gotchas
- Connected mode requires persistent outbound HTTPS connectivity
- Local mode has no API Manager visibility — monitoring is local only
- Cannot switch modes without re-registration
- Local mode YAML schema is versioned — check compatibility with your gateway version

### Related
- [Local Mode YAML](../local-mode-yaml/) — YAML configuration details
- [Docker Standalone](../docker-standalone/) — standalone deployment
