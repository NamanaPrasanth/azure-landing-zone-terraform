# -----------------------------------------------------------------------------
# Spoke virtual network
# Workload network peered to the hub. Each subnet gets its own NSG, and
# subnets flagged route_via_firewall send 0.0.0.0/0 to Azure Firewall.
# -----------------------------------------------------------------------------

locals {
  # Subnets that should force-tunnel egress through the hub firewall.
  firewall_routed_subnets = {
    for k, s in var.subnets : k => s if s.route_via_firewall && var.route_via_firewall
  }
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

resource "azurerm_subnet" "this" {
  for_each = var.subnets

  name                              = "snet-${each.key}"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.spoke.name
  address_prefixes                  = each.value.address_prefixes
  service_endpoints                 = each.value.service_endpoints
  private_endpoint_network_policies = each.value.private_endpoint_network_policies
}

# -----------------------------------------------------------------------------
# Network Security Groups - one per subnet
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "this" {
  for_each = var.subnets

  name                = "nsg-${var.name}-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "security_rule" {
    for_each = each.value.nsg_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = "*"
      destination_port_ranges    = security_rule.value.destination_port_ranges
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "this" {
  for_each = var.subnets

  subnet_id                 = azurerm_subnet.this[each.key].id
  network_security_group_id = azurerm_network_security_group.this[each.key].id
}

# -----------------------------------------------------------------------------
# User-defined route: default route to the hub firewall
# -----------------------------------------------------------------------------

resource "azurerm_route_table" "this" {
  count = var.route_via_firewall ? 1 : 0

  name                          = "rt-${var.name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  bgp_route_propagation_enabled = false
  tags                          = var.tags

  route {
    name                   = "default-to-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = var.firewall_private_ip
  }
}

resource "azurerm_subnet_route_table_association" "this" {
  for_each = local.firewall_routed_subnets

  subnet_id      = azurerm_subnet.this[each.key].id
  route_table_id = azurerm_route_table.this[0].id
}

# -----------------------------------------------------------------------------
# Hub <-> spoke peering (both directions are required)
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-${var.name}-to-hub"
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = var.hub_vnet_id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = var.use_hub_gateway
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-${var.name}"
  resource_group_name          = var.hub_resource_group_name
  virtual_network_name         = var.hub_vnet_name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = var.use_hub_gateway
}
