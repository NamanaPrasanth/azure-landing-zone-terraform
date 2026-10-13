output "action_group_id" {
  description = "Action group ID, reusable by other alerts."
  value       = azurerm_monitor_action_group.this.id
}

output "metric_alert_ids" {
  description = "Map of metric alert key => ID."
  value       = { for k, a in azurerm_monitor_metric_alert.this : k => a.id }
}

output "log_alert_ids" {
  description = "Map of log alert key => ID."
  value       = { for k, a in azurerm_monitor_scheduled_query_rules_alert_v2.this : k => a.id }
}
