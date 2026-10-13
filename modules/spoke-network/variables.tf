variable "name" {
  description = "Base name for spoke resources (e.g. plz-dev-cus-app)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the spoke VNet."
  type        = string
}

variable "address_space" {
  description = "Spoke VNet address space. Must not overlap the hub or other spokes."
  type        = list(string)
}

variable "dns_servers" {
  description = "Custom DNS servers. Point at the firewall IP to use its DNS proxy."
  type        = list(string)
  default     = []
}

variable "subnets" {
  description = "Map of subnet key => settings. The key becomes snet-<key>."
  type = map(object({
    address_prefixes                  = list(string)
    route_via_firewall                = optional(bool, true)
    service_endpoints                 = optional(list(string), [])
    private_endpoint_network_policies = optional(string, "Enabled")
    nsg_rules = optional(list(object({
      name                       = string
      priority                   = number
      direction                  = string
      access                     = string
      protocol                   = string
      destination_port_ranges    = list(string)
      source_address_prefix      = string
      destination_address_prefix = string
    })), [])
  }))
}

variable "route_via_firewall" {
  description = "Create a route table that sends 0.0.0.0/0 to the hub firewall."
  type        = bool
  default     = true
}

variable "firewall_private_ip" {
  description = "Hub firewall private IP (next hop). Required when route_via_firewall is true."
  type        = string
  default     = null
}

variable "hub_vnet_id" {
  description = "Resource ID of the hub VNet."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub VNet."
  type        = string
}

variable "hub_resource_group_name" {
  description = "Resource group of the hub VNet."
  type        = string
}

variable "use_hub_gateway" {
  description = "Use the hub's ExpressRoute/VPN gateway for on-premises routing. Requires a gateway in the hub."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
