output "workspace_id" {
  description = "Log Analytics workspace resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "workspace_name" {
  description = "Log Analytics workspace name."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_customer_id" {
  description = "Workspace GUID used by agents and queries."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "sentinel_rule_ids" {
  description = "Map of Sentinel analytics rule name => ID."
  value       = { for k, r in azurerm_sentinel_alert_rule_scheduled.this : k => r.id }
}
