output "resource_groups" {
  description = "Resource groups created by the landing zone."
  value = {
    management   = azurerm_resource_group.management.name
    connectivity = azurerm_resource_group.connectivity.name
    security     = azurerm_resource_group.security.name
    workload     = azurerm_resource_group.workload.name
  }
}

output "hub_vnet_id" {
  description = "Hub VNet ID."
  value       = module.hub.vnet_id
}

output "spoke_vnet_id" {
  description = "Workload spoke VNet ID."
  value       = module.spoke.vnet_id
}

output "firewall_private_ip" {
  description = "Azure Firewall private IP."
  value       = module.hub.firewall_private_ip
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = module.key_vault.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Central Log Analytics workspace ID."
  value       = module.log_analytics.workspace_id
}

output "aks_cluster_name" {
  description = "AKS cluster name (null when disabled)."
  value       = var.aks_enabled ? module.aks[0].name : null
}

output "aks_get_credentials" {
  description = "Command to fetch kubeconfig (Entra ID auth via kubelogin)."
  value       = var.aks_enabled ? "az aks get-credentials -g ${azurerm_resource_group.workload.name} -n ${module.aks[0].name} && kubelogin convert-kubeconfig -l azurecli" : null
}
