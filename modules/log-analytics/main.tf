# -----------------------------------------------------------------------------
# Central Log Analytics workspace + Microsoft Sentinel
# Every module ships diagnostics here. Sentinel sits on top for SIEM/SOAR.
# -----------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "this" {
  name                = "law-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_in_days
  daily_quota_gb      = var.daily_quota_gb
  tags                = var.tags
}

# Send the subscription Activity Log to the workspace so the AzureActivity
# table is populated for Sentinel analytics and KQL queries.
resource "azurerm_monitor_diagnostic_setting" "activity_log" {
  count = var.subscription_id != null ? 1 : 0

  name                       = "diag-activity-to-law"
  target_resource_id         = "/subscriptions/${var.subscription_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id

  dynamic "enabled_log" {
    for_each = ["Administrative", "Security", "Policy", "Alert", "ServiceHealth", "ResourceHealth"]
    content {
      category = enabled_log.value
    }
  }
}

resource "azurerm_sentinel_log_analytics_workspace_onboarding" "this" {
  count = var.sentinel_enabled ? 1 : 0

  workspace_id = azurerm_log_analytics_workspace.this.id
}

# -----------------------------------------------------------------------------
# Sentinel scheduled analytics rules (KQL). Defaults live in locals.tf.
# Note: the AzureActivity table must exist before Sentinel accepts a rule
# that queries it - it appears a few minutes after the first Activity Log
# event. If the first apply fails here, wait and re-run apply.
# -----------------------------------------------------------------------------

resource "azurerm_sentinel_alert_rule_scheduled" "this" {
  for_each = var.sentinel_enabled ? local.analytics_rules : {}

  name                       = each.key
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.this[0].workspace_id
  display_name               = each.value.display_name
  description                = each.value.description
  severity                   = each.value.severity
  tactics                    = each.value.tactics
  query                      = each.value.query
  query_frequency            = each.value.query_frequency
  query_period               = each.value.query_period
  trigger_operator           = "GreaterThan"
  trigger_threshold          = 0

  depends_on = [azurerm_monitor_diagnostic_setting.activity_log]
}

# Saved KQL queries for day-to-day operations and troubleshooting.
resource "azurerm_log_analytics_saved_search" "this" {
  for_each = local.saved_searches

  name                       = each.key
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  category                   = "Landing Zone"
  display_name               = each.value.display_name
  query                      = each.value.query
}
