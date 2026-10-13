# -----------------------------------------------------------------------------
# Azure Monitor alerting
# One action group, then three kinds of alerts:
#   - Activity Log alerts (Service Health, risky control-plane operations)
#   - Metric alerts (passed in by the caller for any resource)
#   - Log search alerts written in KQL
# -----------------------------------------------------------------------------

resource "azurerm_monitor_action_group" "this" {
  name                = "ag-${var.name}"
  resource_group_name = var.resource_group_name
  short_name          = substr(replace(var.name, "-", ""), 0, 12)
  tags                = var.tags

  dynamic "email_receiver" {
    for_each = var.alert_emails
    content {
      name                    = "email-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# --- Activity Log alerts -------------------------------------------------------

resource "azurerm_monitor_activity_log_alert" "service_health" {
  name                = "ala-${var.name}-service-health"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = [var.subscription_resource_id]
  description         = "Azure Service Health incidents and maintenance affecting this subscription's regions."
  tags                = var.tags

  criteria {
    category = "ServiceHealth"

    service_health {
      events    = ["Incident", "Maintenance", "Security"]
      locations = var.service_health_locations
    }
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

resource "azurerm_monitor_activity_log_alert" "admin_operations" {
  for_each = var.watched_operations

  name                = "ala-${var.name}-${each.key}"
  resource_group_name = var.resource_group_name
  location            = "global"
  scopes              = [var.subscription_resource_id]
  description         = "Fires when ${each.value} succeeds anywhere in the subscription."
  tags                = var.tags

  criteria {
    category       = "Administrative"
    operation_name = each.value
    status         = "Succeeded"
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# --- Metric alerts -------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "this" {
  for_each = var.metric_alerts

  name                = "ma-${var.name}-${each.key}"
  resource_group_name = var.resource_group_name
  scopes              = [each.value.scope_id]
  description         = each.value.description
  severity            = each.value.severity
  frequency           = "PT5M"
  window_size         = each.value.window_size
  tags                = var.tags

  criteria {
    metric_namespace = each.value.metric_namespace
    metric_name      = each.value.metric_name
    aggregation      = each.value.aggregation
    operator         = each.value.operator
    threshold        = each.value.threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# --- Log search (KQL) alerts ---------------------------------------------------

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "this" {
  for_each = var.log_alerts

  name                 = "lsa-${var.name}-${each.key}"
  resource_group_name  = var.resource_group_name
  location             = var.location
  scopes               = [var.log_analytics_workspace_id]
  description          = each.value.description
  severity             = each.value.severity
  evaluation_frequency = each.value.evaluation_frequency
  window_duration      = each.value.window_duration
  tags                 = var.tags

  # Tables such as KubePodInventory only exist once data arrives, so skip
  # validation at create time.
  skip_query_validation = true

  criteria {
    query                   = each.value.query
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = each.value.threshold

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.this.id]
  }
}
