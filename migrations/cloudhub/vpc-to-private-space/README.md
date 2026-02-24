## VPC to CloudHub 2.0 Private Space
> Migrate from CloudHub 1.0 VPC to CloudHub 2.0 Private Space for enhanced network isolation

### When to Use
- Moving applications from CloudHub 1.0 to CloudHub 2.0
- Need Kubernetes-based deployment with better resource control
- VPC peering or VPN connections need migration to Private Space networking
- Compliance requirements demand improved network isolation

### Configuration / Code

#### 1. Audit Current VPC Configuration

```bash
# List existing VPCs
anypoint-cli-v4 cloudhub vpc list --organization "My Org"

# Get VPC details
anypoint-cli-v4 cloudhub vpc describe --name "Production-VPC" --organization "My Org"

# List VPN connections
anypoint-cli-v4 cloudhub vpn list --organization "My Org"
```

#### 2. Create Private Space

```bash
# Create private space
anypoint-cli-v4 runtime-mgr ps create \
    --name "Production-PS" \
    --region us-east-1 \
    --organization "My Org"

# Configure private network (CIDR must not overlap with existing networks)
anypoint-cli-v4 runtime-mgr ps network create \
    --name "prod-network" \
    --private-space "Production-PS" \
    --cidr "10.0.0.0/16" \
    --organization "My Org"
```

#### 3. Configure TLS Context

```bash
# Upload TLS certificate for inbound traffic
anypoint-cli-v4 runtime-mgr ps tls-context create \
    --name "prod-tls" \
    --private-space "Production-PS" \
    --keystore-path ./keystore.jks \
    --keystore-password "${KEYSTORE_PASS}" \
    --organization "My Org"
```

#### 4. Network Mapping (VPC → Private Space)

| VPC Feature | Private Space Equivalent |
|---|---|
| VPC Peering | Transit Gateway attachment |
| VPN (IPsec) | VPN connection to Private Space |
| DLB (Dedicated Load Balancer) | Ingress configuration |
| Firewall Rules | Network policies |
| Static IPs | NAT Gateway with static IPs |

#### 5. Deploy Application to Private Space

```bash
# Deploy using CLI
anypoint-cli-v4 runtime-mgr app deploy \
    --name "my-api" \
    --target "Production-PS" \
    --runtime-version "4.6.0" \
    --replicas 2 \
    --vcores 0.5 \
    --artifact ./target/my-api-1.0.0-mule-application.jar \
    --organization "My Org"
```

### How It Works
1. CloudHub 2.0 Private Spaces replace VPCs with Kubernetes-based isolated environments
2. Each Private Space gets its own dedicated infrastructure within Anypoint Platform
3. Networking is managed through Transit Gateway (replaces VPC peering) and VPN connections
4. Applications deploy as containers with configurable replicas and resource allocation

### Migration Checklist
- [ ] Document all VPC settings (CIDR, peering, VPN, firewall rules)
- [ ] Create Private Space with non-overlapping CIDR ranges
- [ ] Set up Transit Gateway or VPN connections
- [ ] Configure TLS/ingress to replace DLB
- [ ] Migrate firewall rules to network policies
- [ ] Deploy test application and verify connectivity
- [ ] Migrate production apps one by one
- [ ] Decommission old VPC after all apps are migrated

### Gotchas
- Private Space CIDR blocks cannot overlap with connected networks (on-prem, other cloud)
- DLB SSL certificates must be re-uploaded to the Private Space TLS context
- Private Space pricing differs from VPC — review cost implications
- DNS resolution may need reconfiguration for internal service discovery
- VPC peering connections must be recreated as Transit Gateway attachments

### Related
- [ch1-app-to-ch2](../ch1-app-to-ch2/) — Full app migration guide
- [on-prem-to-ch2](../on-prem-to-ch2/) — On-premises migration
- [cicd-for-ch2](../../build-tools/cicd-for-ch2/) — CI/CD pipeline updates
