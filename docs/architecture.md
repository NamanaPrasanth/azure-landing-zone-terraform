# Architecture and design decisions

## Resource groups

Resources are split by platform function, following the Cloud Adoption Framework pattern of separating connectivity, management, security and workloads. Each group can have its own RBAC, policy and lifecycle.

| Resource group | Contents | Typical owner |
|---|---|---|
| `rg-<name>-connectivity` | Hub VNet, Azure Firewall, ExpressRoute gateway, private DNS zones | Network team |
| `rg-<name>-management` | Log Analytics, Sentinel, alerts, Recovery Services vault | Cloud operations |
| `rg-<name>-security` | Key Vault | Security team |
| `rg-<name>-workload` | Spoke VNet, AKS | Application team |

Names follow `<type>-<prefix>-<environment>-<region>` (for example `aks-plz-dev-cus`), and every resource group carries `Environment`, `Owner` and `CostCenter` tags, which Azure Policy requires.

## IP address plan

| Network | CIDR | Notes |
|---|---|---|
| Hub VNet | `10.0.0.0/22` | |
| `AzureFirewallSubnet` | `10.0.0.0/26` | /26 is the Azure minimum |
| `GatewaySubnet` | `10.0.0.64/27` | Room for ExpressRoute + VPN coexistence |
| `snet-management` | `10.0.1.0/24` | Jump hosts, self-hosted build agents |
| Spoke VNet | `10.1.0.0/16` | |
| `snet-aks` | `10.1.0.0/22` | Nodes only; pods use the overlay range |
| `snet-app` | `10.1.4.0/24` | VMs / App Service integration |
| `snet-private-endpoints` | `10.1.5.0/24` | Not routed through the firewall |
| AKS pod CIDR (overlay) | `192.168.0.0/16` | Not routable outside the cluster |
| AKS service CIDR | `172.16.0.0/16` | |

Subnets are computed with `cidrsubnet()` from the VNet range, so changing the address space in one variable re-plans everything consistently.

## Traffic flow

**Spoke to internet:** subnet → route table (`0.0.0.0/0 → firewall private IP`) → Azure Firewall policy evaluation → internet. Default action is deny; the baseline rule collection allows NTP, the AKS tunnel ports to `AzureCloud.<region>`, the `AzureKubernetesService` and `WindowsUpdate` FQDN tags, and any FQDNs passed in `allowed_egress_fqdns`.

**Spoke to on-premises:** spoke → peering (`use_remote_gateways`) → hub ExpressRoute gateway → circuit. Enabled when `expressroute_gateway_enabled = true`.

**Name resolution:** spokes use the firewall as their DNS server (DNS proxy). The firewall forwards to Azure DNS from the hub, which resolves `privatelink.vaultcore.azure.net` records because that zone is linked to the hub VNet. This keeps FQDN-based firewall rules and private endpoints consistent.

**Private endpoints:** the private-endpoints subnet deliberately has no route to the firewall. Return traffic from a private endpoint does not follow UDRs the same way, so routing it through the firewall would create asymmetric paths.

## Key decisions

| Decision | Why | Trade-off |
|---|---|---|
| Hub-and-spoke rather than Virtual WAN | Full control over routing and firewall rules; cheaper at small scale | More peering and route management as spokes grow |
| Azure Firewall Standard | Threat intelligence, FQDN tags and DNS proxy cover the baseline | IDPS and TLS inspection need Premium |
| Firewall Policy instead of classic rules | Rules are a separate resource, so workload teams can add their own rule collection groups | |
| AKS `outbound_type = userDefinedRouting` | All cluster egress is inspected and logged by the firewall | Firewall must be in place before the cluster is created (`depends_on`) |
| User-assigned identity for the AKS control plane | It can be granted Network Contributor on the subnet and route table *before* the cluster exists | One more resource to manage |
| Azure CNI Overlay | Pods don't consume VNet IPs, so the node subnet can stay small | Pods are not directly reachable from the VNet |
| Key Vault with RBAC + private endpoint | Access is governed by Entra ID roles and audited; no public exposure | Clients must be on the network or peered |
| Policy built-ins looked up by display name | No hard-coded GUIDs in code | Display names must match exactly |
| Policy rollout with `enforce = false` first | Shows the compliance impact before anything is blocked | Two-step rollout |
| Explicit `*_enabled` booleans for optional resources | `count` must be known at plan time; checking whether an ID is null fails on a first apply because the ID isn't known yet | Slightly more variables |
| Remote state in Azure Storage with Entra ID auth | State locking via blob lease; no storage account keys | Bootstrap script needed before first init |
| OIDC from GitHub Actions | No long-lived client secret to rotate or leak | One-time federated credential setup |

## Security controls summary

| Area | Control |
|---|---|
| Network | Default-deny egress through Azure Firewall; NSG on every subnet; no public IPs in workload RGs (policy) |
| Identity | Entra ID auth for AKS with local accounts disabled; Key Vault RBAC; managed identities; OIDC for CI |
| Data | Key Vault purge protection; encryption at host on AKS nodes; storage secure-transfer policy |
| Governance | Allowed regions, required tags, tag inheritance, data-protection audit/deny |
| Detection | Sentinel analytics for privileged role assignments, Key Vault deletion, NSG rule changes |
| Resilience | Zone-redundant firewall and AKS node pools; geo-redundant backup vault with cross-region restore |
| Supply chain | checkov and tflint in CI; provider versions pinned; lock file committed for the root module |
