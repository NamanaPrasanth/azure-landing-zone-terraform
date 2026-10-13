variable "name" {
  description = "Base name used for all hub resources (e.g. plz-dev-cus-hub)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the hub resources."
  type        = string
}

variable "address_space" {
  description = "Hub VNet address space."
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers for the hub VNet. Empty list uses Azure DNS."
  type        = list(string)
  default     = []
}

variable "firewall_subnet_prefix" {
  description = "CIDR for AzureFirewallSubnet (minimum /26)."
  type        = string
}

variable "gateway_subnet_prefix" {
  description = "CIDR for GatewaySubnet (/27 or larger recommended)."
  type        = string
}

variable "management_subnet_prefix" {
  description = "CIDR for the management subnet (jump hosts, build agents)."
  type        = string
}

variable "firewall_enabled" {
  description = "Deploy Azure Firewall. Disable to save cost in short-lived demos."
  type        = bool
  default     = true
}

variable "threat_intelligence_mode" {
  description = "Firewall threat intelligence mode: Alert, Deny or Off."
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Alert", "Deny", "Off"], var.threat_intelligence_mode)
    error_message = "Must be Alert, Deny or Off."
  }
}

variable "management_allowed_cidrs" {
  description = "Private CIDRs (e.g. on-premises admin ranges) allowed to RDP/SSH into the management subnet. Empty = deny."
  type        = list(string)
  default     = []
}

variable "availability_zones" {
  description = "Availability zones for the firewall and gateway public IPs."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "spoke_address_spaces" {
  description = "Spoke CIDRs allowed as sources in firewall rules."
  type        = list(string)
}

variable "allowed_egress_fqdns" {
  description = "Extra FQDNs spokes may reach over HTTPS (e.g. package mirrors)."
  type        = list(string)
  default     = []
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for firewall diagnostics."
  type        = string
  default     = null
}

variable "diagnostics_enabled" {
  description = "Send diagnostics to log_analytics_workspace_id. A plain bool keeps count known at plan time."
  type        = bool
  default     = true
}

variable "expressroute_gateway_enabled" {
  description = "Deploy an ExpressRoute virtual network gateway in the hub."
  type        = bool
  default     = false
}

variable "expressroute_gateway_sku" {
  description = "ExpressRoute gateway SKU (zone-redundant SKUs end in AZ)."
  type        = string
  default     = "ErGw1AZ"

  validation {
    condition     = contains(["Standard", "HighPerformance", "UltraPerformance", "ErGw1AZ", "ErGw2AZ", "ErGw3AZ"], var.expressroute_gateway_sku)
    error_message = "Must be a valid ExpressRoute gateway SKU."
  }
}

variable "expressroute_circuit_id" {
  description = "Resource ID of a provisioned ExpressRoute circuit to connect. Null to skip."
  type        = string
  default     = null
}

variable "expressroute_authorization_key" {
  description = "Authorization key when the circuit lives in another subscription."
  type        = string
  default     = null
  sensitive   = true
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
