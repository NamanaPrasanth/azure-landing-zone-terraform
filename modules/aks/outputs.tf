output "id" {
  description = "AKS cluster ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federated credentials."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Kubelet identity object ID (grant AcrPull to this)."
  value       = try(azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id, null)
}

output "node_resource_group" {
  description = "Auto-generated resource group holding the node VMSS."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
