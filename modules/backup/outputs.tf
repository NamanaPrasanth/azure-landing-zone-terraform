output "vault_id" {
  description = "Recovery Services vault ID."
  value       = azurerm_recovery_services_vault.this.id
}

output "vault_name" {
  description = "Recovery Services vault name."
  value       = azurerm_recovery_services_vault.this.name
}

output "vm_policy_id" {
  description = "Daily VM backup policy ID."
  value       = azurerm_backup_policy_vm.daily.id
}
