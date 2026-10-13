variable "name" {
  description = "Base name (vault becomes rsv-<name>)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault."
  type        = string
}

variable "storage_mode_type" {
  description = "GeoRedundant, ZoneRedundant or LocallyRedundant."
  type        = string
  default     = "GeoRedundant"

  validation {
    condition     = contains(["GeoRedundant", "ZoneRedundant", "LocallyRedundant"], var.storage_mode_type)
    error_message = "Must be GeoRedundant, ZoneRedundant or LocallyRedundant."
  }
}

variable "cross_region_restore_enabled" {
  description = "Allow restores into the paired region (GeoRedundant only)."
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Allow public network access to the vault."
  type        = bool
  default     = true
}

variable "timezone" {
  description = "Timezone for the backup schedule."
  type        = string
  default     = "Central Standard Time"
}

variable "backup_time" {
  description = "Daily backup time (HH:MM, 24h)."
  type        = string
  default     = "23:00"
}

variable "retention_daily" {
  description = "Daily recovery points to keep."
  type        = number
  default     = 14
}

variable "retention_weekly" {
  description = "Weekly recovery points to keep."
  type        = number
  default     = 8
}

variable "retention_monthly" {
  description = "Monthly recovery points to keep."
  type        = number
  default     = 12
}

variable "protected_vm_ids" {
  description = "Map of static key => VM resource ID to protect with the daily policy."
  type        = map(string)
  default     = {}
}

variable "log_analytics_workspace_id" {
  description = "Workspace for backup reports."
  type        = string
  default     = null
}

variable "diagnostics_enabled" {
  description = "Send diagnostics to log_analytics_workspace_id. A plain bool keeps count known at plan time."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
