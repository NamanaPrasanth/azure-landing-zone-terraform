# Azure Monitor Alerting

Alerting for the platform.

- **Action group** with email receivers (common alert schema)
- **Activity Log alerts**: Service Health incidents and maintenance, plus high-risk operations (Key Vault, policy assignment or firewall deletion)
- **Metric alerts** passed in as a map, so any resource can be covered (e.g. firewall health, AKS node CPU)
- **Log search alerts** in KQL against the central workspace (e.g. pods in `CrashLoopBackOff`)

## Usage

```hcl
module "monitoring" {
  source = "../../modules/monitoring"

  name                       = "plz-dev-cus"
  location                   = "centralus"
  resource_group_name        = "rg-plz-dev-cus-management"
  subscription_resource_id   = "/subscriptions/00000000-0000-0000-0000-000000000000"
  log_analytics_workspace_id = module.log_analytics.workspace_id
  alert_emails               = ["cloud-ops@example.com"]

  metric_alerts = {
    firewall-health = {
      scope_id         = module.hub.firewall_id
      description      = "Azure Firewall health below 90%"
      metric_namespace = "Microsoft.Network/azureFirewalls"
      metric_name      = "FirewallHealth"
      aggregation      = "Average"
      operator         = "LessThan"
      threshold        = 90
    }
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
| [azurerm_monitor_action_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_action_group) | resource |
| [azurerm_monitor_activity_log_alert.admin_operations](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_activity_log_alert) | resource |
| [azurerm_monitor_activity_log_alert.service_health](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_activity_log_alert) | resource |
| [azurerm_monitor_metric_alert.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_metric_alert) | resource |
| [azurerm_monitor_scheduled_query_rules_alert_v2.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_scheduled_query_rules_alert_v2) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Region for log search alerts. | `string` | n/a | yes |
| log\_analytics\_workspace\_id | Workspace queried by log search alerts. | `string` | n/a | yes |
| name | Base name for alerting resources. | `string` | n/a | yes |
| resource\_group\_name | Resource group for alerting resources. | `string` | n/a | yes |
| subscription\_resource\_id | Subscription resource ID used as the scope of Activity Log alerts. | `string` | n/a | yes |
| alert\_emails | Email addresses that receive alerts. | `list(string)` | `[]` | no |
| log\_alerts | Map of KQL log search alerts against the workspace. | <pre>map(object({<br/>    description          = string<br/>    query                = string<br/>    threshold            = optional(number, 0)<br/>    severity             = optional(number, 2)<br/>    evaluation_frequency = optional(string, "PT15M")<br/>    window_duration      = optional(string, "PT15M")<br/>  }))</pre> | `{}` | no |
| metric\_alerts | Map of metric alerts for any resource. | <pre>map(object({<br/>    scope_id         = string<br/>    description      = string<br/>    metric_namespace = string<br/>    metric_name      = string<br/>    aggregation      = string<br/>    operator         = string<br/>    threshold        = number<br/>    severity         = optional(number, 2)<br/>    window_size      = optional(string, "PT15M")<br/>  }))</pre> | `{}` | no |
| service\_health\_locations | Regions to watch in Service Health (use display names, e.g. "Central US", plus "Global"). | `list(string)` | <pre>[<br/>  "Global"<br/>]</pre> | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| watched\_operations | Map of key => Activity Log operation name that should raise an alert. | `map(string)` | <pre>{<br/>  "fw-delete": "Microsoft.Network/azureFirewalls/delete",<br/>  "kv-delete": "Microsoft.KeyVault/vaults/delete",<br/>  "policy-delete": "Microsoft.Authorization/policyAssignments/delete"<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| action\_group\_id | Action group ID, reusable by other alerts. |
| log\_alert\_ids | Map of log alert key => ID. |
| metric\_alert\_ids | Map of metric alert key => ID. |
<!-- END_TF_DOCS -->
