# -----------------------------------------------------------------------------
# Hub virtual network
# Central point of connectivity: Azure Firewall inspects all spoke egress
# traffic, and the optional ExpressRoute gateway connects on-premises sites.
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.address_space
  dns_servers         = var.dns_servers
  tags                = var.tags
}

# Subnet names below are mandated by Azure and cannot be changed.
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.management_subnet_prefix]
}

resource "azurerm_network_security_group" "management" {
  name                = "nsg-${var.name}-management"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  security_rule {
    name                       = "allow-rdp-ssh-from-allowed-ranges"
    priority                   = 100
    direction                  = "Inbound"
    access                     = length(var.management_allowed_cidrs) > 0 ? "Allow" : "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefixes    = length(var.management_allowed_cidrs) > 0 ? var.management_allowed_cidrs : ["0.0.0.0/0"]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "deny-internet-inbound"
    priority                   = 4000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

# -----------------------------------------------------------------------------
# Azure Firewall (Standard) with a Firewall Policy
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "firewall" {
  count = var.firewall_enabled ? 1 : 0

  name                = "pip-afw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_firewall_policy" "this" {
  count = var.firewall_enabled ? 1 : 0

  name                     = "afwp-${var.name}"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  sku                      = "Standard"
  threat_intelligence_mode = var.threat_intelligence_mode
  tags                     = var.tags

  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall" "this" {
  count = var.firewall_enabled ? 1 : 0

  name                = "afw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  firewall_policy_id  = azurerm_firewall_policy.this[0].id
  zones               = var.availability_zones
  tags                = var.tags

  ip_configuration {
    name                 = "ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall[0].id
  }
}

# Baseline egress rules. Spoke traffic is denied by default; only what is
# listed here (plus any caller-supplied FQDNs) is allowed out to the internet.
resource "azurerm_firewall_policy_rule_collection_group" "baseline" {
  count = var.firewall_enabled ? 1 : 0

  name               = "rcg-baseline"
  firewall_policy_id = azurerm_firewall_policy.this[0].id
  priority           = 200

  network_rule_collection {
    name     = "net-allow-core"
    priority = 100
    action   = "Allow"

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }

    # Required for AKS control plane <-> node tunnel when using UDR egress.
    rule {
      name                  = "allow-aks-tunnel"
      protocols             = ["UDP", "TCP"]
      source_addresses      = var.spoke_address_spaces
      destination_addresses = ["AzureCloud.${var.location}"]
      destination_ports     = ["1194", "9000", "443"]
    }
  }

  application_rule_collection {
    name     = "app-allow-platform"
    priority = 200
    action   = "Allow"

    rule {
      name                  = "allow-aks-fqdn-tag"
      source_addresses      = var.spoke_address_spaces
      destination_fqdn_tags = ["AzureKubernetesService"]

      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
    }

    rule {
      name                  = "allow-windows-update"
      source_addresses      = var.spoke_address_spaces
      destination_fqdn_tags = ["WindowsUpdate"]

      protocols {
        type = "Https"
        port = 443
      }
    }

    dynamic "rule" {
      for_each = length(var.allowed_egress_fqdns) > 0 ? [1] : []
      content {
        name              = "allow-custom-fqdns"
        source_addresses  = var.spoke_address_spaces
        destination_fqdns = var.allowed_egress_fqdns

        protocols {
          type = "Https"
          port = 443
        }
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  count = var.firewall_enabled && var.diagnostics_enabled ? 1 : 0

  name                           = "diag-to-law"
  target_resource_id             = azurerm_firewall.this[0].id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category_group = "allLogs"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# -----------------------------------------------------------------------------
# Optional ExpressRoute gateway + circuit connection (hybrid connectivity)
# Off by default because the gateway is billed hourly.
# -----------------------------------------------------------------------------

resource "azurerm_public_ip" "er_gateway" {
  count = var.expressroute_gateway_enabled ? 1 : 0

  name                = "pip-ergw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = var.availability_zones
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "expressroute" {
  count = var.expressroute_gateway_enabled ? 1 : 0

  name                = "ergw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "ExpressRoute"
  sku                 = var.expressroute_gateway_sku
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig"
    public_ip_address_id          = azurerm_public_ip.er_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }
}

resource "azurerm_virtual_network_gateway_connection" "expressroute" {
  count = var.expressroute_gateway_enabled && var.expressroute_circuit_id != null ? 1 : 0

  name                       = "conn-er-${var.name}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  type                       = "ExpressRoute"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.expressroute[0].id
  express_route_circuit_id   = var.expressroute_circuit_id
  authorization_key          = var.expressroute_authorization_key
  tags                       = var.tags
}
