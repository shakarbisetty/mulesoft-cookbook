## Hybrid Deployment to Unified Agent
> Migrate from Mule Agent (hybrid) to Unified Agent for on-premises Mule runtime management

### When to Use
- Currently using the legacy Mule Agent for on-prem runtime management
- Anypoint Platform shows deprecation warnings for the hybrid agent
- Need unified monitoring and management across on-prem and cloud deployments
- Want consistent deployment experience with CloudHub 2.0 and RTF

### Configuration / Code

#### 1. Check Current Agent Version

```bash
# Check Mule Agent version
$MULE_HOME/bin/amc_setup --version

# Check agent status
$MULE_HOME/bin/amc_setup -S
```

#### 2. Install Unified Agent

```bash
# Download Unified Agent from Anypoint Platform
# Runtime Manager > Servers > Add Server

# Stop Mule runtime
$MULE_HOME/bin/mule stop

# Remove old agent
rm -rf $MULE_HOME/plugins/mule-agent-plugin-*

# Install unified agent
$MULE_HOME/bin/amc_setup -H <registration-token>

# Verify installation
ls $MULE_HOME/plugins/ | grep agent

# Restart Mule runtime
$MULE_HOME/bin/mule start
```

#### 3. Agent Configuration

```yaml
# $MULE_HOME/conf/mule-agent.yml
transports:
  websocket.transport:
    enabled: true
    security:
      keyStorePassword: "${secure::agent.keystore.password}"
      keyStoreAlias: agent
      keyStoreAliasPassword: "${secure::agent.alias.password}"

  rest.agent.transport:
    enabled: true
    port: 9999
    security:
      keyStorePassword: "${secure::agent.keystore.password}"

services:
  mule.agent.application.service:
    enabled: true
  mule.agent.domain.service:
    enabled: true
  mule.agent.monitoring.service:
    enabled: true
    frequencyTimeUnit: SECONDS
    frequency: 30
```

#### 4. Server Group / Cluster Configuration

```bash
# Register server in a server group (via Anypoint Platform UI or CLI)
anypoint-cli-v4 runtime-mgr server-group add \
    --name "prod-cluster" \
    --server "prod-server-1" \
    --environment "Production"

# Or create a cluster
anypoint-cli-v4 runtime-mgr cluster create \
    --name "prod-cluster" \
    --servers "prod-server-1,prod-server-2" \
    --multicast false \
    --environment "Production"
```

#### 5. Verify Agent Connectivity

```bash
# Check agent logs
tail -f $MULE_HOME/logs/mule_agent.log

# Verify server appears in Runtime Manager
anypoint-cli-v4 runtime-mgr server list --environment "Production"
```

### How It Works
1. The Unified Agent replaces the legacy Mule Agent with improved communication protocols
2. It provides consistent management APIs across on-prem, CloudHub 2.0, and RTF
3. The agent maintains a WebSocket connection to Anypoint Platform for real-time management
4. Monitoring data is collected and sent to Anypoint Monitoring with the same format as cloud deployments

### Migration Checklist
- [ ] Document current agent version and configuration
- [ ] Schedule maintenance window for agent upgrade
- [ ] Stop Mule runtime
- [ ] Remove old agent plugin
- [ ] Install unified agent with registration token
- [ ] Configure `mule-agent.yml` with security settings
- [ ] Restart Mule runtime
- [ ] Verify server appears in Runtime Manager
- [ ] Test application deployment via Runtime Manager
- [ ] Verify monitoring data flows to Anypoint Monitoring

### Gotchas
- Agent upgrade requires Mule runtime restart — plan for downtime
- Registration tokens expire — generate a fresh token before installation
- Firewall must allow outbound WebSocket connections to Anypoint Platform
- Server groups/clusters may need to be recreated after agent upgrade
- Legacy agent custom extensions may not be compatible with unified agent
- Ensure sufficient disk space for agent logs and temporary files

### Related
- [on-prem-to-ch2](../on-prem-to-ch2/) — Full cloud migration
- [cloudhub-to-rtf](../cloudhub-to-rtf/) — Runtime Fabric option
- [anypoint-to-otel](../../monitoring/anypoint-to-otel/) — Monitoring migration
