# Hub Network

Central connectivity hub for the landing zone.

- Hub VNet with the Azure-mandated `AzureFirewallSubnet` and `GatewaySubnet`, plus a management subnet protected by an NSG
- **Azure Firewall (Standard)** driven by a **Firewall Policy**: threat intelligence in Deny mode, DNS proxy, and a baseline rule collection group (NTP, AKS egress via the `AzureKubernetesService` FQDN tag, Windows Update, optional custom FQDNs)
- Optional **ExpressRoute gateway** and circuit connection for on-premises connectivity (off by default because it is billed hourly)
- Firewall logs sent to Log Analytics in resource-specific (`Dedicated`) tables such as `AZFWNetworkRule`

## Usage

```hcl
module "hub" {
  source = "../../modules/hub-network"

  name                       = "plz-dev-cus-hub"
  location                   = "centralus"
  resource_group_name        = "rg-plz-dev-cus-connectivity"
  address_space              = ["10.0.0.0/22"]
  firewall_subnet_prefix     = "10.0.0.0/26"
  gateway_subnet_prefix      = "10.0.0.64/27"
  management_subnet_prefix   = "10.0.1.0/24"
  spoke_address_spaces       = ["10.1.0.0/16"]
  log_analytics_workspace_id = module.log_analytics.workspace_id

  expressroute_gateway_enabled = true
  expressroute_circuit_id      = "/subscriptions/.../expressRouteCircuits/er-onprem"
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| azurerm | >= 4.40.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | 4.81.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_firewall.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall) | resource |
| [azurerm_firewall_policy.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy) | resource |
| [azurerm_firewall_policy_rule_collection_group.baseline](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/firewall_policy_rule_collection_group) | resource |
| [azurerm_monitor_diagnostic_setting.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_network_security_group.management](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_public_ip.er_gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_public_ip.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) | resource |
| [azurerm_subnet.firewall](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.gateway](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet.management](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.management](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_virtual_network.hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_gateway.expressroute](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway) | resource |
| [azurerm_virtual_network_gateway_connection.expressroute](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_gateway_connection) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| address\_space | Hub VNet address space. | `list(string)` | n/a | yes |
| firewall\_subnet\_prefix | CIDR for AzureFirewallSubnet (minimum /26). | `string` | n/a | yes |
| gateway\_subnet\_prefix | CIDR for GatewaySubnet (/27 or larger recommended). | `string` | n/a | yes |
| location | Azure region. | `string` | n/a | yes |
| management\_subnet\_prefix | CIDR for the management subnet (jump hosts, build agents). | `string` | n/a | yes |
| name | Base name used for all hub resources (e.g. plz-dev-cus-hub). | `string` | n/a | yes |
| resource\_group\_name | Resource group that holds the hub resources. | `string` | n/a | yes |
| spoke\_address\_spaces | Spoke CIDRs allowed as sources in firewall rules. | `list(string)` | n/a | yes |
| allowed\_egress\_fqdns | Extra FQDNs spokes may reach over HTTPS (e.g. package mirrors). | `list(string)` | `[]` | no |
| availability\_zones | Availability zones for the firewall and gateway public IPs. | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| diagnostics\_enabled | Send diagnostics to log\_analytics\_workspace\_id. A plain bool keeps count known at plan time. | `bool` | `true` | no |
| dns\_servers | Custom DNS servers for the hub VNet. Empty list uses Azure DNS. | `list(string)` | `[]` | no |
| expressroute\_authorization\_key | Authorization key when the circuit lives in another subscription. | `string` | `null` | no |
| expressroute\_circuit\_id | Resource ID of a provisioned ExpressRoute circuit to connect. Null to skip. | `string` | `null` | no |
| expressroute\_gateway\_enabled | Deploy an ExpressRoute virtual network gateway in the hub. | `bool` | `false` | no |
| expressroute\_gateway\_sku | ExpressRoute gateway SKU (zone-redundant SKUs end in AZ). | `string` | `"ErGw1AZ"` | no |
| firewall\_enabled | Deploy Azure Firewall. Disable to save cost in short-lived demos. | `bool` | `true` | no |
| log\_analytics\_workspace\_id | Log Analytics workspace for firewall diagnostics. | `string` | `null` | no |
| management\_allowed\_cidrs | Private CIDRs (e.g. on-premises admin ranges) allowed to RDP/SSH into the management subnet. Empty = deny. | `list(string)` | `[]` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| threat\_intelligence\_mode | Firewall threat intelligence mode: Alert, Deny or Off. | `string` | `"Deny"` | no |

## Outputs

| Name | Description |
|------|-------------|
| expressroute\_gateway\_id | ExpressRoute gateway ID (null when not deployed). |
| firewall\_id | Azure Firewall resource ID (null when disabled). |
| firewall\_policy\_id | Firewall Policy ID, so workloads can add their own rule collection groups. |
| firewall\_private\_ip | Private IP of Azure Firewall, used as next hop by spoke route tables. |
| management\_subnet\_id | Management subnet ID. |
| vnet\_id | Hub VNet resource ID. |
| vnet\_name | Hub VNet name. |
<!-- END_TF_DOCS -->
