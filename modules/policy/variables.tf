variable "name" {
  description = "Prefix for policy definitions and assignments."
  type        = string
}

variable "location" {
  description = "Location for policy assignment managed identities."
  type        = string
}

variable "subscription_resource_id" {
  description = "Subscription resource ID, e.g. /subscriptions/00000000-0000-0000-0000-000000000000."
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[0-9a-fA-F-]{36}$", var.subscription_resource_id))
    error_message = "Must be in the form /subscriptions/<guid>."
  }
}

variable "allowed_locations" {
  description = "Regions where resources may be deployed."
  type        = list(string)
}

variable "required_tags" {
  description = "Tags that every resource group must carry."
  type        = list(string)
  default     = ["Environment", "Owner", "CostCenter"]
}

variable "inherited_tags" {
  description = "Tags copied from the resource group onto resources that lack them."
  type        = list(string)
  default     = ["Environment", "CostCenter"]
}

variable "data_protection_effect" {
  description = "Effect for Key Vault deletion protection and storage secure transfer (Audit, Deny, Disabled)."
  type        = string
  default     = "Audit"

  validation {
    condition     = contains(["Audit", "Deny", "Disabled"], var.data_protection_effect)
    error_message = "Must be Audit, Deny or Disabled."
  }
}

variable "deny_public_ip_resource_group_ids" {
  description = "Map of static key => resource group ID where public IPs are denied."
  type        = map(string)
  default     = {}
}

variable "enforce" {
  description = "false = DoNotEnforce mode (evaluate and report only). Useful for a first rollout."
  type        = bool
  default     = true
}
