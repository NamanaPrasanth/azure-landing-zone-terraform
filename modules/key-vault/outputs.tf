output "id" {
  description = "Key Vault resource ID."
  value       = azurerm_key_vault.this.id
}

output "name" {
  description = "Key Vault name."
  value       = azurerm_key_vault.this.name
}

output "vault_uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.this.vault_uri
}

output "private_endpoint_ip" {
  description = "Private IP of the vault's private endpoint."
  value       = var.private_endpoint_enabled ? azurerm_private_endpoint.this[0].private_service_connection[0].private_ip_address : null
}
