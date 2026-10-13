# Log Analytics + Microsoft Sentinel

Central observability and SIEM workspace.

- **Log Analytics workspace** with retention and a daily ingestion cap to control cost
- Subscription **Activity Log** routed to the workspace (populates the `AzureActivity` table)
- **Microsoft Sentinel** onboarding with scheduled analytics rules written in **KQL**:
  - privileged role assignments (Owner / Contributor / User Access Administrator)
  - Key Vault deletion
  - NSG rule changes
- **Saved KQL queries** for operations: firewall denies, Key Vault access failures, AKS container restarts, changes by caller
- Extra analytics rules can be passed in through `extra_analytics_rules`

> The `AzureActivity` table appears a few minutes after the first Activity Log event. If Sentinel rejects a rule on the very first apply, wait and run apply again.

## Usage

```hcl
module "log_analytics" {
  source = "../../modules/log-analytics"

  name                = "plz-dev-cus"
  location            = "centralus"
  resource_group_name = "rg-plz-dev-cus-management"
  subscription_id     = "00000000-0000-0000-0000-000000000000"
  retention_in_days   = 90
  sentinel_enabled    = true
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
| [azurerm_log_analytics_saved_search.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_saved_search) | resource |
| [azurerm_log_analytics_workspace.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_monitor_diagnostic_setting.activity_log](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_sentinel_alert_rule_scheduled.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_alert_rule_scheduled) | resource |
| [azurerm_sentinel_log_analytics_workspace_onboarding.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/sentinel_log_analytics_workspace_onboarding) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Azure region. | `string` | n/a | yes |
| name | Base name (workspace becomes law-<name>). | `string` | n/a | yes |
| resource\_group\_name | Resource group for the workspace. | `string` | n/a | yes |
| daily\_quota\_gb | Daily ingestion cap in GB to protect against runaway cost. -1 = unlimited. | `number` | `5` | no |
| extra\_analytics\_rules | Additional Sentinel scheduled rules, merged with the defaults. | <pre>map(object({<br/>    display_name    = string<br/>    description     = string<br/>    severity        = string<br/>    tactics         = list(string)<br/>    query           = string<br/>    query_frequency = string<br/>    query_period    = string<br/>  }))</pre> | `{}` | no |
| retention\_in\_days | Interactive retention in days (30-730). | `number` | `90` | no |
| sentinel\_enabled | Onboard Microsoft Sentinel and create analytics rules. | `bool` | `true` | no |
| subscription\_id | Subscription whose Activity Log is sent to the workspace. Null to skip. | `string` | `null` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| sentinel\_rule\_ids | Map of Sentinel analytics rule name => ID. |
| workspace\_customer\_id | Workspace GUID used by agents and queries. |
| workspace\_id | Log Analytics workspace resource ID. |
| workspace\_name | Log Analytics workspace name. |
<!-- END_TF_DOCS -->
