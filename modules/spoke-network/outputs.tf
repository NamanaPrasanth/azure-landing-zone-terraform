output "vnet_id" {
  description = "Spoke VNet ID."
  value       = azurerm_virtual_network.spoke.id
}

output "vnet_name" {
  description = "Spoke VNet name."
  value       = azurerm_virtual_network.spoke.name
}

output "subnet_ids" {
  description = "Map of subnet key => subnet ID."
  value       = { for k, s in azurerm_subnet.this : k => s.id }
}

output "route_table_id" {
  description = "Route table ID (null when not routing via firewall)."
  value       = var.route_via_firewall ? azurerm_route_table.this[0].id : null
}

output "route_table_associations" {
  description = "Route table association IDs. Depend on this before creating AKS with UDR egress."
  value       = [for a in azurerm_subnet_route_table_association.this : a.id]
}
