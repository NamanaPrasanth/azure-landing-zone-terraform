variable "name" {
  description = "Base name (cluster becomes aks-<name>)."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for the cluster."
  type        = string
}

variable "tenant_id" {
  description = "Microsoft Entra tenant ID for cluster authentication."
  type        = string
}

variable "admin_group_object_ids" {
  description = "Entra ID group object IDs granted cluster-admin."
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Kubernetes version. Null = AKS default; patch upgrades are automatic."
  type        = string
  default     = null
}

variable "sku_tier" {
  description = "Free, Standard (uptime SLA) or Premium."
  type        = string
  default     = "Standard"
}

variable "private_cluster_enabled" {
  description = "Private API server. Requires a jump host or build agent inside the network."
  type        = bool
  default     = false
}

variable "api_server_authorized_ip_ranges" {
  description = "Public CIDRs allowed to reach a public API server. Empty = open (use private_cluster_enabled in production)."
  type        = list(string)
  default     = []
}

variable "host_encryption_enabled" {
  description = "Encrypt temp disks and caches at the VM host. Needs the Microsoft.Compute/EncryptionAtHost feature registered."
  type        = bool
  default     = true
}

variable "subnet_id" {
  description = "Subnet for AKS nodes."
  type        = string
}

variable "network_contributor_scopes" {
  description = "Map of static key => resource ID (subnet, route table) where the control plane gets Network Contributor."
  type        = map(string)
  default     = {}
}

variable "outbound_type" {
  description = "userDefinedRouting (egress via firewall) or loadBalancer."
  type        = string
  default     = "userDefinedRouting"

  validation {
    condition     = contains(["userDefinedRouting", "loadBalancer"], var.outbound_type)
    error_message = "outbound_type must be userDefinedRouting or loadBalancer."
  }
}

variable "pod_cidr" {
  description = "Overlay pod CIDR (not routable outside the cluster)."
  type        = string
  default     = "192.168.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR."
  type        = string
  default     = "172.16.0.0/16"
}

variable "dns_service_ip" {
  description = "CoreDNS service IP, must be inside service_cidr."
  type        = string
  default     = "172.16.0.10"
}

variable "availability_zones" {
  description = "Zones for node pools."
  type        = list(string)
  default     = ["1", "2", "3"]
}

variable "system_node_vm_size" {
  description = "VM size for the system pool."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "system_node_min_count" {
  description = "Minimum system nodes."
  type        = number
  default     = 2
}

variable "system_node_max_count" {
  description = "Maximum system nodes."
  type        = number
  default     = 3
}

variable "user_node_pool_enabled" {
  description = "Create a separate user node pool for workloads."
  type        = bool
  default     = true
}

variable "user_node_vm_size" {
  description = "VM size for the user pool."
  type        = string
  default     = "Standard_D4ds_v5"
}

variable "user_node_min_count" {
  description = "Minimum user nodes."
  type        = number
  default     = 1
}

variable "user_node_max_count" {
  description = "Maximum user nodes."
  type        = number
  default     = 5
}

variable "log_analytics_workspace_id" {
  description = "Workspace for Container Insights and control plane logs."
  type        = string
}

variable "key_vault_access_enabled" {
  description = "Grant the CSI driver identity Key Vault Secrets User on key_vault_id."
  type        = bool
  default     = true
}

variable "key_vault_id" {
  description = "Key Vault the CSI driver may read secrets from."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
