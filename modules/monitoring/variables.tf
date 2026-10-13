variable "name" {
  description = "Base name for alerting resources."
  type        = string
}

variable "location" {
  description = "Region for log search alerts."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for alerting resources."
  type        = string
}

variable "subscription_resource_id" {
  description = "Subscription resource ID used as the scope of Activity Log alerts."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Workspace queried by log search alerts."
  type        = string
}

variable "alert_emails" {
  description = "Email addresses that receive alerts."
  type        = list(string)
  default     = []
}

variable "service_health_locations" {
  description = "Regions to watch in Service Health (use display names, e.g. \"Central US\", plus \"Global\")."
  type        = list(string)
  default     = ["Global"]
}

variable "watched_operations" {
  description = "Map of key => Activity Log operation name that should raise an alert."
  type        = map(string)
  default = {
    "kv-delete"     = "Microsoft.KeyVault/vaults/delete"
    "policy-delete" = "Microsoft.Authorization/policyAssignments/delete"
    "fw-delete"     = "Microsoft.Network/azureFirewalls/delete"
  }
}

variable "metric_alerts" {
  description = "Map of metric alerts for any resource."
  type = map(object({
    scope_id         = string
    description      = string
    metric_namespace = string
    metric_name      = string
    aggregation      = string
    operator         = string
    threshold        = number
    severity         = optional(number, 2)
    window_size      = optional(string, "PT15M")
  }))
  default = {}
}

variable "log_alerts" {
  description = "Map of KQL log search alerts against the workspace."
  type = map(object({
    description          = string
    query                = string
    threshold            = optional(number, 0)
    severity             = optional(number, 2)
    evaluation_frequency = optional(string, "PT15M")
    window_duration      = optional(string, "PT15M")
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
