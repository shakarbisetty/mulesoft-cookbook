## Terraform Anypoint Provider
> Manage Business Groups, environments, Connected Apps, VPCs, and DLBs with Terraform

### When to Use
- You want infrastructure-as-code for Anypoint Platform organizational resources
- You need reproducible environment setup across multiple orgs or business groups
- You want drift detection and state management for platform configuration

### Configuration

**versions.tf**
```hcl
terraform {
  required_version = ">= 1.5"

  required_providers {
    anypoint = {
      source  = "mulesoft-anypoint/anypoint"
      version = "~> 1.6"
    }
  }

  backend "s3" {
    bucket = "my-terraform-state"
    key    = "anypoint/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "anypoint" {
  client_id     = var.connected_app_client_id
  client_secret = var.connected_app_client_secret
  access_token  = ""  # Leave empty when using Connected App
}
```

**variables.tf**
```hcl
variable "connected_app_client_id" {
  type        = string
  sensitive   = true
  description = "Connected App client ID with Org Admin scope"
}

variable "connected_app_client_secret" {
  type        = string
  sensitive   = true
  description = "Connected App client secret"
}

variable "org_id" {
  type        = string
  description = "Root organization ID"
}

variable "environments" {
  type = map(object({
    type = string  # "sandbox" or "production"
  }))
  default = {
    DEV     = { type = "sandbox" }
    QA      = { type = "sandbox" }
    STAGING = { type = "sandbox" }
    PROD    = { type = "production" }
  }
}
```

**main.tf**
```hcl
# Business Group
resource "anypoint_bg" "integration_bg" {
  name          = "Integration"
  parent_org_id = var.org_id
  owner_id      = var.org_id

  entitlements {
    vcores_production  = 4.0
    vcores_sandbox     = 2.0
    static_ips         = 2
    vpcs               = 1
    load_balancers     = 1
  }
}

# Environments
resource "anypoint_env" "envs" {
  for_each = var.environments

  org_id = anypoint_bg.integration_bg.id
  name   = each.key
  type   = each.value.type
}

# VPC
resource "anypoint_vpc" "main_vpc" {
  org_id        = anypoint_bg.integration_bg.id
  name          = "integration-vpc"
  region        = "us-east-2"
  cidr_block    = "10.0.0.0/24"
  is_default    = true

  firewall_rules {
    cidr_block = "0.0.0.0/0"
    from_port  = 8081
    to_port    = 8082
    protocol   = "tcp"
  }

  firewall_rules {
    cidr_block = "10.0.0.0/8"
    from_port  = 8091
    to_port    = 8092
    protocol   = "tcp"
  }
}

# Connected App for CI/CD
resource "anypoint_connected_app" "cicd_app" {
  org_id       = anypoint_bg.integration_bg.id
  display_name = "CI/CD Pipeline"
  grant_types  = ["client_credentials"]
  audience     = "internal"

  scope {
    org_id  = anypoint_bg.integration_bg.id
    env_id  = anypoint_env.envs["DEV"].id
    scope   = "CloudHub Developer"
  }

  scope {
    org_id  = anypoint_bg.integration_bg.id
    env_id  = anypoint_env.envs["QA"].id
    scope   = "CloudHub Developer"
  }

  scope {
    org_id  = anypoint_bg.integration_bg.id
    env_id  = anypoint_env.envs["PROD"].id
    scope   = "CloudHub Developer"
  }
}

# DLB
resource "anypoint_dlb" "main_dlb" {
  org_id     = anypoint_bg.integration_bg.id
  vpc_id     = anypoint_vpc.main_vpc.id
  name       = "integration-dlb"
  state      = "started"
  workers    = 2

  ssl_endpoints {
    certificate = file("certs/integration.pem")
    private_key = file("certs/integration.key")
    mappings {
      input_uri  = "api.example.com"
      app_name   = "order-api"
      app_uri    = "/"
    }
  }
}
```

**outputs.tf**
```hcl
output "business_group_id" {
  value = anypoint_bg.integration_bg.id
}

output "environment_ids" {
  value = { for k, v in anypoint_env.envs : k => v.id }
}

output "connected_app_client_id" {
  value     = anypoint_connected_app.cicd_app.client_id
  sensitive = true
}

output "vpc_id" {
  value = anypoint_vpc.main_vpc.id
}
```

### How It Works
1. The Anypoint Terraform provider authenticates via a Connected App with Org Admin scope
2. `anypoint_bg` creates or manages a Business Group with vCore entitlements
3. `anypoint_env` creates environments using `for_each` for DRY configuration
4. `anypoint_vpc` provisions a VPC with firewall rules for inbound traffic
5. `anypoint_connected_app` creates a scoped Connected App for CI/CD pipelines
6. State is stored in S3 for team collaboration and drift detection

### Gotchas
- The Connected App used by Terraform must have Org Admin scope — use a separate app from CI/CD
- VPC changes can cause downtime; use `lifecycle { prevent_destroy = true }` on production VPCs
- DLB SSL certificates must be PEM-encoded; do not commit private keys to Git
- The Anypoint provider does not cover all platform resources; check the provider docs for coverage gaps
- State file contains sensitive values; encrypt the S3 bucket and restrict access

### Related
- [cloudformation-vpcs](../cloudformation-vpcs/) — AWS CloudFormation for VPC networking
- [ansible-on-prem](../ansible-on-prem/) — Ansible for on-prem runtimes
- [no-rebuild-promotion](../../environments/no-rebuild-promotion/) — Promote artifacts across TF-managed environments
