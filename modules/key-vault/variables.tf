variable "name" {
  description = "Globally unique Key Vault name (3-24 chars, letters, numbers, hyphens)."
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]{1,22}[a-zA-Z0-9]$", var.name))
    error_message = "Key Vault name must be 3-24 characters, start with a letter and contain only letters, numbers and hyphens."
  }
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the vault."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID."
  type        = string
}

variable "sku_name" {
  description = "standard or premium (HSM-backed keys)."
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Soft-delete retention (7-90 days)."
  type        = number
  default     = 90
}

variable "public_network_access_enabled" {
  description = "Allow public network access. Keep false and use the private endpoint."
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "Public IP ranges allowed through the vault firewall (only used if public access is on)."
  type        = list(string)
  default     = []
}

variable "role_assignments" {
  description = "Map of key => { role_definition_name, principal_id } granted at vault scope."
  type = map(object({
    role_definition_name = string
    principal_id         = string
  }))
  default = {}
}

variable "private_endpoint_enabled" {
  description = "Create a private endpoint in private_endpoint_subnet_id."
  type        = bool
  default     = true
}

variable "private_dns_zone_enabled" {
  description = "Register the private endpoint in private_dns_zone_id."
  type        = bool
  default     = true
}

variable "private_endpoint_subnet_id" {
  description = "Subnet for the private endpoint."
  type        = string
  default     = null
}

variable "private_dns_zone_id" {
  description = "ID of the privatelink.vaultcore.azure.net zone."
  type        = string
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "Workspace for audit logs."
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
