# Spoke Network

Workload VNet peered to the hub.

- Subnets defined as a map, so new subnets are added with data rather than code
- One **NSG per subnet** with rules passed in as objects
- **User-defined route** `0.0.0.0/0 -> Azure Firewall` on subnets that set `route_via_firewall` (the private-endpoints subnet opts out)
- **Bidirectional peering** with gateway transit, so spokes can reach on-premises through the hub's ExpressRoute gateway

## Usage

```hcl
module "spoke" {
  source = "../../modules/spoke-network"

  name                    = "plz-dev-cus-app"
  location                = "centralus"
  resource_group_name     = "rg-plz-dev-cus-workload"
  address_space           = ["10.1.0.0/16"]
  hub_vnet_id             = module.hub.vnet_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = "rg-plz-dev-cus-connectivity"
  firewall_private_ip     = module.hub.firewall_private_ip

  subnets = {
    aks               = { address_prefixes = ["10.1.0.0/22"] }
    private-endpoints = { address_prefixes = ["10.1.5.0/24"], route_via_firewall = false }
  }
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
| [azurerm_network_security_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_security_group) | resource |
| [azurerm_route_table.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/route_table) | resource |
| [azurerm_subnet.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) | resource |
| [azurerm_subnet_network_security_group_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_network_security_group_association) | resource |
| [azurerm_subnet_route_table_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet_route_table_association) | resource |
| [azurerm_virtual_network.spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) | resource |
| [azurerm_virtual_network_peering.hub_to_spoke](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |
| [azurerm_virtual_network_peering.spoke_to_hub](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network_peering) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| address\_space | Spoke VNet address space. Must not overlap the hub or other spokes. | `list(string)` | n/a | yes |
| hub\_resource\_group\_name | Resource group of the hub VNet. | `string` | n/a | yes |
| hub\_vnet\_id | Resource ID of the hub VNet. | `string` | n/a | yes |
| hub\_vnet\_name | Name of the hub VNet. | `string` | n/a | yes |
| location | Azure region. | `string` | n/a | yes |
| name | Base name for spoke resources (e.g. plz-dev-cus-app). | `string` | n/a | yes |
| resource\_group\_name | Resource group for the spoke VNet. | `string` | n/a | yes |
| subnets | Map of subnet key => settings. The key becomes snet-<key>. | <pre>map(object({<br/>    address_prefixes                  = list(string)<br/>    route_via_firewall                = optional(bool, true)<br/>    service_endpoints                 = optional(list(string), [])<br/>    private_endpoint_network_policies = optional(string, "Enabled")<br/>    nsg_rules = optional(list(object({<br/>      name                       = string<br/>      priority                   = number<br/>      direction                  = string<br/>      access                     = string<br/>      protocol                   = string<br/>      destination_port_ranges    = list(string)<br/>      source_address_prefix      = string<br/>      destination_address_prefix = string<br/>    })), [])<br/>  }))</pre> | n/a | yes |
| dns\_servers | Custom DNS servers. Point at the firewall IP to use its DNS proxy. | `list(string)` | `[]` | no |
| firewall\_private\_ip | Hub firewall private IP (next hop). Required when route\_via\_firewall is true. | `string` | `null` | no |
| route\_via\_firewall | Create a route table that sends 0.0.0.0/0 to the hub firewall. | `bool` | `true` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| use\_hub\_gateway | Use the hub's ExpressRoute/VPN gateway for on-premises routing. Requires a gateway in the hub. | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| route\_table\_associations | Route table association IDs. Depend on this before creating AKS with UDR egress. |
| route\_table\_id | Route table ID (null when not routing via firewall). |
| subnet\_ids | Map of subnet key => subnet ID. |
| vnet\_id | Spoke VNet ID. |
| vnet\_name | Spoke VNet name. |
<!-- END_TF_DOCS -->
