# Azure Backup

Business continuity and disaster recovery for IaaS workloads.

- **Recovery Services vault**: geo-redundant storage with **cross-region restore**; soft delete is always on
- **Daily VM backup policy** with tiered retention (14 daily, 8 weekly, 12 monthly by default) and 5-day instant restore
- Optional protection of existing VMs via `protected_vm_ids`
- Backup job and policy logs sent to Log Analytics for backup reporting

## Usage

```hcl
module "backup" {
  source = "../../modules/backup"

  name                       = "plz-dev-cus"
  location                   = "centralus"
  resource_group_name        = "rg-plz-dev-cus-management"
  log_analytics_workspace_id = module.log_analytics.workspace_id

  protected_vm_ids = {
    app01 = "/subscriptions/.../virtualMachines/vm-app01"
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
| [azurerm_backup_policy_vm.daily](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/backup_policy_vm) | resource |
| [azurerm_backup_protected_vm.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/backup_protected_vm) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_recovery_services_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/recovery_services_vault) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Azure region. | `string` | n/a | yes |
| name | Base name (vault becomes rsv-<name>). | `string` | n/a | yes |
| resource\_group\_name | Resource group for the vault. | `string` | n/a | yes |
| backup\_time | Daily backup time (HH:MM, 24h). | `string` | `"23:00"` | no |
| cross\_region\_restore\_enabled | Allow restores into the paired region (GeoRedundant only). | `bool` | `true` | no |
| diagnostics\_enabled | Send diagnostics to log\_analytics\_workspace\_id. A plain bool keeps count known at plan time. | `bool` | `true` | no |
| log\_analytics\_workspace\_id | Workspace for backup reports. | `string` | `null` | no |
| protected\_vm\_ids | Map of static key => VM resource ID to protect with the daily policy. | `map(string)` | `{}` | no |
| public\_network\_access\_enabled | Allow public network access to the vault. | `bool` | `true` | no |
| retention\_daily | Daily recovery points to keep. | `number` | `14` | no |
| retention\_monthly | Monthly recovery points to keep. | `number` | `12` | no |
| retention\_weekly | Weekly recovery points to keep. | `number` | `8` | no |
| storage\_mode\_type | GeoRedundant, ZoneRedundant or LocallyRedundant. | `string` | `"GeoRedundant"` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| timezone | Timezone for the backup schedule. | `string` | `"Central Standard Time"` | no |

## Outputs

| Name | Description |
|------|-------------|
| vault\_id | Recovery Services vault ID. |
| vault\_name | Recovery Services vault name. |
| vm\_policy\_id | Daily VM backup policy ID. |
<!-- END_TF_DOCS -->
