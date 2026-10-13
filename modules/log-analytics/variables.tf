variable "name" {
  description = "Base name (workspace becomes law-<name>)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the workspace."
  type        = string
}

variable "retention_in_days" {
  description = "Interactive retention in days (30-730)."
  type        = number
  default     = 90

  validation {
    condition     = var.retention_in_days >= 30 && var.retention_in_days <= 730
    error_message = "retention_in_days must be between 30 and 730."
  }
}

variable "daily_quota_gb" {
  description = "Daily ingestion cap in GB to protect against runaway cost. -1 = unlimited."
  type        = number
  default     = 5
}

variable "subscription_id" {
  description = "Subscription whose Activity Log is sent to the workspace. Null to skip."
  type        = string
  default     = null
}

variable "sentinel_enabled" {
  description = "Onboard Microsoft Sentinel and create analytics rules."
  type        = bool
  default     = true
}

variable "extra_analytics_rules" {
  description = "Additional Sentinel scheduled rules, merged with the defaults."
  type = map(object({
    display_name    = string
    description     = string
    severity        = string
    tactics         = list(string)
    query           = string
    query_frequency = string
    query_period    = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
