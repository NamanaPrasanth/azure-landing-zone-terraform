# -----------------------------------------------------------------------------
# Azure Backup
# Recovery Services vault (geo-redundant, cross-region restore; soft delete is
# always on) plus a daily VM policy with tiered retention.
# -----------------------------------------------------------------------------

resource "azurerm_recovery_services_vault" "this" {
  name                          = "rsv-${var.name}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  sku                           = "Standard"
  storage_mode_type             = var.storage_mode_type
  cross_region_restore_enabled  = var.storage_mode_type == "GeoRedundant" ? var.cross_region_restore_enabled : false
  public_network_access_enabled = var.public_network_access_enabled
  tags                          = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_backup_policy_vm" "daily" {
  name                           = "bkpol-vm-daily"
  resource_group_name            = var.resource_group_name
  recovery_vault_name            = azurerm_recovery_services_vault.this.name
  timezone                       = var.timezone
  instant_restore_retention_days = 5

  backup {
    frequency = "Daily"
    time      = var.backup_time
  }

  retention_daily {
    count = var.retention_daily
  }

  retention_weekly {
    count    = var.retention_weekly
    weekdays = ["Sunday"]
  }

  retention_monthly {
    count    = var.retention_monthly
    weekdays = ["Sunday"]
    weeks    = ["First"]
  }
}

# Optionally protect existing VMs (map of static key => VM resource ID).
resource "azurerm_backup_protected_vm" "this" {
  for_each = var.protected_vm_ids

  resource_group_name = var.resource_group_name
  recovery_vault_name = azurerm_recovery_services_vault.this.name
  source_vm_id        = each.value
  backup_policy_id    = azurerm_backup_policy_vm.daily.id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  count = var.diagnostics_enabled ? 1 : 0

  name                           = "diag-to-law"
  target_resource_id             = azurerm_recovery_services_vault.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = ["CoreAzureBackup", "AddonAzureBackupJobs", "AddonAzureBackupPolicy", "AddonAzureBackupProtectedInstance"]
    content {
      category = enabled_log.value
    }
  }
}
