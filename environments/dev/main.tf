# =============================================================================
# Azure Landing Zone - dev environment
# Composes the reusable modules into a hub-and-spoke landing zone.
# =============================================================================

data "azurerm_client_config" "current" {}

locals {
  name = "${var.prefix}-${var.environment}-${var.location_short}"

  tags = merge({
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    ManagedBy   = "Terraform"
    Repository  = "azure-landing-zone-terraform"
  }, var.extra_tags)

  subscription_resource_id = "/subscriptions/${var.subscription_id}"
}

resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

# -----------------------------------------------------------------------------
# Resource groups - one per platform function (CAF-style separation)
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "management" {
  name     = "rg-${local.name}-management"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "connectivity" {
  name     = "rg-${local.name}-connectivity"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "security" {
  name     = "rg-${local.name}-security"
  location = var.location
  tags     = local.tags
}

resource "azurerm_resource_group" "workload" {
  name     = "rg-${local.name}-workload"
  location = var.location
  tags     = local.tags
}

# -----------------------------------------------------------------------------
# Management: Log Analytics + Sentinel
# -----------------------------------------------------------------------------

module "log_analytics" {
  source = "../../modules/log-analytics"

  name                = local.name
  location            = var.location
  resource_group_name = azurerm_resource_group.management.name
  subscription_id     = var.subscription_id
  retention_in_days   = var.log_retention_days
  sentinel_enabled    = var.sentinel_enabled
  tags                = local.tags
}

# -----------------------------------------------------------------------------
# Connectivity: hub network with Azure Firewall (+ optional ExpressRoute)
# -----------------------------------------------------------------------------

module "hub" {
  source = "../../modules/hub-network"

  name                       = "${local.name}-hub"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.connectivity.name
  address_space              = [var.hub_address_space]
  firewall_subnet_prefix     = cidrsubnet(var.hub_address_space, 4, 0) # /26
  gateway_subnet_prefix      = cidrsubnet(var.hub_address_space, 5, 2) # /27
  management_subnet_prefix   = cidrsubnet(var.hub_address_space, 2, 1) # /24
  firewall_enabled           = var.firewall_enabled
  spoke_address_spaces       = [var.spoke_address_space]
  allowed_egress_fqdns       = var.allowed_egress_fqdns
  log_analytics_workspace_id = module.log_analytics.workspace_id

  expressroute_gateway_enabled   = var.expressroute_gateway_enabled
  expressroute_circuit_id        = var.expressroute_circuit_id
  expressroute_authorization_key = var.expressroute_authorization_key

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Workload spoke
# -----------------------------------------------------------------------------

module "spoke" {
  source = "../../modules/spoke-network"

  name                    = "${local.name}-app"
  location                = var.location
  resource_group_name     = azurerm_resource_group.workload.name
  address_space           = [var.spoke_address_space]
  hub_vnet_id             = module.hub.vnet_id
  hub_vnet_name           = module.hub.vnet_name
  hub_resource_group_name = azurerm_resource_group.connectivity.name
  use_hub_gateway         = var.expressroute_gateway_enabled
  route_via_firewall      = var.firewall_enabled
  firewall_private_ip     = module.hub.firewall_private_ip

  # Firewall DNS proxy gives spokes consistent private DNS resolution.
  dns_servers = var.firewall_enabled ? [module.hub.firewall_private_ip] : []

  subnets = {
    aks = {
      address_prefixes = [cidrsubnet(var.spoke_address_space, 6, 0)] # /22
    }
    app = {
      address_prefixes = [cidrsubnet(var.spoke_address_space, 8, 4)] # /24
      nsg_rules = [
        {
          name                       = "allow-https-from-vnet"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          destination_port_ranges    = ["443"]
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        },
        {
          name                       = "deny-internet-inbound"
          priority                   = 4000
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          destination_port_ranges    = ["0-65535"]
          source_address_prefix      = "Internet"
          destination_address_prefix = "*"
        },
      ]
    }
    private-endpoints = {
      address_prefixes   = [cidrsubnet(var.spoke_address_space, 8, 5)] # /24
      route_via_firewall = false
    }
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Private DNS for Key Vault, linked to hub and spoke
# -----------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.connectivity.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  for_each = {
    hub   = module.hub.vnet_id
    spoke = module.spoke.vnet_id
  }

  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.connectivity.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = each.value
  tags                  = local.tags
}

# -----------------------------------------------------------------------------
# Security: Key Vault
# -----------------------------------------------------------------------------

module "key_vault" {
  source = "../../modules/key-vault"

  name                       = "kv-${local.name}-${random_string.suffix.result}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.security.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.spoke.subnet_ids["private-endpoints"]
  private_dns_zone_id        = azurerm_private_dns_zone.key_vault.id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  role_assignments = {
    deployer = {
      role_definition_name = "Key Vault Administrator"
      principal_id         = data.azurerm_client_config.current.object_id
    }
  }

  tags = local.tags
}

# -----------------------------------------------------------------------------
# Workload: AKS
# -----------------------------------------------------------------------------

module "aks" {
  source = "../../modules/aks"
  count  = var.aks_enabled ? 1 : 0

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.workload.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids     = var.aks_admin_group_object_ids
  subnet_id                  = module.spoke.subnet_ids["aks"]
  outbound_type              = var.firewall_enabled ? "userDefinedRouting" : "loadBalancer"
  log_analytics_workspace_id = module.log_analytics.workspace_id
  key_vault_id               = module.key_vault.id
  system_node_vm_size        = var.aks_node_vm_size
  user_node_vm_size          = var.aks_node_vm_size

  network_contributor_scopes = merge(
    { subnet = module.spoke.subnet_ids["aks"] },
    var.firewall_enabled ? { route_table = module.spoke.route_table_id } : {}
  )

  tags = local.tags

  # Egress rules and the default route must exist before AKS is created,
  # otherwise node bootstrap cannot reach the control plane.
  depends_on = [module.hub, module.spoke]
}

# -----------------------------------------------------------------------------
# Management: monitoring and backup
# -----------------------------------------------------------------------------

module "monitoring" {
  source = "../../modules/monitoring"

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.management.name
  subscription_resource_id   = local.subscription_resource_id
  log_analytics_workspace_id = module.log_analytics.workspace_id
  alert_emails               = var.alert_emails
  service_health_locations   = var.service_health_locations

  metric_alerts = merge(
    var.firewall_enabled ? {
      firewall-health = {
        scope_id         = module.hub.firewall_id
        description      = "Azure Firewall health dropped below 90%."
        metric_namespace = "Microsoft.Network/azureFirewalls"
        metric_name      = "FirewallHealth"
        aggregation      = "Average"
        operator         = "LessThan"
        threshold        = 90
        severity         = 1
      }
    } : {},
    var.aks_enabled ? {
      aks-node-cpu = {
        scope_id         = module.aks[0].id
        description      = "AKS node CPU above 80% for 15 minutes."
        metric_namespace = "Microsoft.ContainerService/managedClusters"
        metric_name      = "node_cpu_usage_percentage"
        aggregation      = "Average"
        operator         = "GreaterThan"
        threshold        = 80
      }
    } : {}
  )

  log_alerts = var.aks_enabled ? {
    aks-crashloop = {
      description = "One or more pods are in CrashLoopBackOff."
      query       = <<-KQL
        KubePodInventory
        | where ContainerStatusReason == "CrashLoopBackOff"
        | summarize by Namespace, Name
      KQL
    }
  } : {}

  tags = local.tags
}

module "backup" {
  source = "../../modules/backup"

  name                       = local.name
  location                   = var.location
  resource_group_name        = azurerm_resource_group.management.name
  log_analytics_workspace_id = module.log_analytics.workspace_id
  tags                       = local.tags
}

# -----------------------------------------------------------------------------
# Governance: Azure Policy
# -----------------------------------------------------------------------------

module "policy" {
  source = "../../modules/policy"

  name                     = local.name
  location                 = var.location
  subscription_resource_id = local.subscription_resource_id
  allowed_locations        = var.allowed_locations
  required_tags            = ["Environment", "Owner", "CostCenter"]
  inherited_tags           = ["Environment", "CostCenter"]
  data_protection_effect   = var.policy_data_protection_effect
  enforce                  = var.policy_enforce

  deny_public_ip_resource_group_ids = {
    workload = azurerm_resource_group.workload.id
  }
}
