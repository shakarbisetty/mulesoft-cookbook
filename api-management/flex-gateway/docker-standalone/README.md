## Flex Gateway Docker Standalone
> Run Flex Gateway as a standalone Docker container for non-Kubernetes environments.

### When to Use
- VM-based or bare-metal deployments
- Development and testing environments
- Simple single-host API gateway

### Configuration / Code

```bash
# Register the gateway
docker run --entrypoint flexctl -w /registration \
  -v "$(pwd)":/registration mulesoft/flex-gateway:1.6 \
  register my-gateway \
  --token=$REGISTRATION_TOKEN \
  --organization=$ORG_ID \
  --connected=true

# Run the gateway
docker run -d --name flex-gateway \
  -v "$(pwd)":/usr/local/share/mulesoft/flex-gateway/conf.d \
  -p 8081:8081 \
  mulesoft/flex-gateway:1.6
```

### How It Works
1. `flexctl register` creates a registration file with credentials
2. The gateway container mounts this file and connects to Anypoint Platform
3. APIs and policies are managed through API Manager
4. Port 8081 serves as the gateway listener

### Gotchas
- Registration file contains secrets — do not commit to version control
- Container restart requires the registration volume mount
- `--connected=true` needs outbound HTTPS to Anypoint; use `--connected=false` for air-gapped
- Docker networking: use `--network host` or proper port mapping

### Related
- [K8s Ingress](../k8s-ingress/) — Kubernetes deployment
- [Connected vs Local](../connected-vs-local/) — mode comparison
