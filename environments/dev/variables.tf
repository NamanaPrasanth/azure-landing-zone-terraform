# --- Identity & naming ---------------------------------------------------------

variable "subscription_id" {
  description = "Target Azure subscription ID."
  type        = string
}

variable "prefix" {
  description = "Short organisation/project prefix used in every resource name."
  type        = string
  default     = "plz"

  validation {
    condition     = can(regex("^[a-z0-9]{2,5}$", var.prefix))
    error_message = "prefix must be 2-5 lowercase letters or digits."
  }
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Primary Azure region."
  type        = string
  default     = "centralus"
}

variable "location_short" {
  description = "Short region code used in names."
  type        = string
  default     = "cus"
}

variable "owner" {
  description = "Owner tag value (team or person)."
  type        = string
}

variable "cost_center" {
  description = "CostCenter tag value."
  type        = string
}

variable "extra_tags" {
  description = "Additional tags merged into the defaults."
  type        = map(string)
  default     = {}
}

# --- Networking ----------------------------------------------------------------

variable "hub_address_space" {
  description = "Hub VNet CIDR (/22 expected; subnets are carved with cidrsubnet)."
  type        = string
  default     = "10.0.0.0/22"
}

variable "spoke_address_space" {
  description = "Workload spoke VNet CIDR (/16 expected)."
  type        = string
  default     = "10.1.0.0/16"
}

variable "firewall_enabled" {
  description = "Deploy Azure Firewall and route spoke egress through it."
  type        = bool
  default     = true
}

variable "allowed_egress_fqdns" {
  description = "Extra FQDNs the spoke may reach on 443."
  type        = list(string)
  default     = []
}

variable "expressroute_gateway_enabled" {
  description = "Deploy an ExpressRoute gateway in the hub."
  type        = bool
  default     = false
}

variable "expressroute_circuit_id" {
  description = "Existing ExpressRoute circuit to connect (optional)."
  type        = string
  default     = null
}

variable "expressroute_authorization_key" {
  description = "Circuit authorization key (cross-subscription circuits)."
  type        = string
  default     = null
  sensitive   = true
}

# --- Management ----------------------------------------------------------------

variable "log_retention_days" {
  description = "Log Analytics retention in days."
  type        = number
  default     = 90
}

variable "sentinel_enabled" {
  description = "Onboard Microsoft Sentinel."
  type        = bool
  default     = true
}

variable "alert_emails" {
  description = "Recipients for Azure Monitor alerts."
  type        = list(string)
  default     = []
}

variable "service_health_locations" {
  description = "Service Health regions to watch (display names)."
  type        = list(string)
  default     = ["Global", "Central US"]
}

# --- Workload ------------------------------------------------------------------

variable "aks_enabled" {
  description = "Deploy the AKS cluster."
  type        = bool
  default     = true
}

variable "aks_admin_group_object_ids" {
  description = "Entra ID groups with cluster-admin on AKS."
  type        = list(string)
  default     = []
}

variable "aks_node_vm_size" {
  description = "VM size for AKS node pools."
  type        = string
  default     = "Standard_D4ds_v5"
}

# --- Governance ----------------------------------------------------------------

variable "allowed_locations" {
  description = "Regions permitted by Azure Policy."
  type        = list(string)
  default     = ["centralus", "eastus2"]
}

variable "policy_data_protection_effect" {
  description = "Audit, Deny or Disabled for Key Vault / Storage guardrails."
  type        = string
  default     = "Audit"
}

variable "policy_enforce" {
  description = "Enforce policies (false = report-only DoNotEnforce mode)."
  type        = bool
  default     = true
}
