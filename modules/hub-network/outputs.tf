output "vnet_id" {
  description = "Hub VNet resource ID."
  value       = azurerm_virtual_network.hub.id
}

output "vnet_name" {
  description = "Hub VNet name."
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Private IP of Azure Firewall, used as next hop by spoke route tables."
  value       = var.firewall_enabled ? azurerm_firewall.this[0].ip_configuration[0].private_ip_address : null
}

output "firewall_id" {
  description = "Azure Firewall resource ID (null when disabled)."
  value       = var.firewall_enabled ? azurerm_firewall.this[0].id : null
}

output "firewall_policy_id" {
  description = "Firewall Policy ID, so workloads can add their own rule collection groups."
  value       = var.firewall_enabled ? azurerm_firewall_policy.this[0].id : null
}

output "management_subnet_id" {
  description = "Management subnet ID."
  value       = azurerm_subnet.management.id
}

output "expressroute_gateway_id" {
  description = "ExpressRoute gateway ID (null when not deployed)."
  value       = var.expressroute_gateway_enabled ? azurerm_virtual_network_gateway.expressroute[0].id : null
}
