# -----------------------------------------------------------------------------
# Azure Kubernetes Service
# Entra ID + Azure RBAC only (local accounts disabled), Azure CNI Overlay,
# egress through the hub firewall (UDR), Container Insights, Key Vault CSI
# driver, Workload Identity and Azure Policy add-on.
# -----------------------------------------------------------------------------

# User-assigned identity for the control plane. Created up front so it can be
# granted Network Contributor on the subnet/route table BEFORE the cluster
# exists - required when outbound_type is userDefinedRouting.
resource "azurerm_user_assigned_identity" "control_plane" {
  name                = "id-aks-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_role_assignment" "network" {
  for_each = var.network_contributor_scopes

  scope                = each.value
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.control_plane.principal_id
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "aks-${var.name}"
  kubernetes_version  = var.kubernetes_version
  sku_tier            = var.sku_tier
  node_resource_group = "rg-${var.name}-aks-nodes"
  tags                = var.tags

  private_cluster_enabled           = var.private_cluster_enabled
  local_account_disabled            = true
  role_based_access_control_enabled = true
  azure_policy_enabled              = true
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    vnet_subnet_id               = var.subnet_id
    zones                        = var.availability_zones
    auto_scaling_enabled         = true
    min_count                    = var.system_node_min_count
    max_count                    = var.system_node_max_count
    max_pods                     = 50
    os_disk_type                 = "Ephemeral"
    os_disk_size_gb              = 64
    host_encryption_enabled      = var.host_encryption_enabled
    only_critical_addons_enabled = true
    temporary_name_for_rotation  = "systemtmp"
    tags                         = var.tags

    upgrade_settings {
      max_surge = "33%"
    }
  }

  dynamic "api_server_access_profile" {
    for_each = length(var.api_server_authorized_ip_ranges) > 0 && !var.private_cluster_enabled ? [1] : []
    content {
      authorized_ip_ranges = var.api_server_authorized_ip_ranges
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.control_plane.id]
  }

  azure_active_directory_role_based_access_control {
    tenant_id              = var.tenant_id
    admin_group_object_ids = var.admin_group_object_ids
    azure_rbac_enabled     = true
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    outbound_type       = var.outbound_type
    load_balancer_sku   = "standard"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
  }

  oms_agent {
    log_analytics_workspace_id      = var.log_analytics_workspace_id
    msi_auth_for_monitoring_enabled = true
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  maintenance_window_auto_upgrade {
    frequency   = "Weekly"
    interval    = 1
    day_of_week = "Sunday"
    start_time  = "02:00"
    duration    = 4
    utc_offset  = "+00:00"
  }

  lifecycle {
    # Autoscaler owns the node count; upgrades are handled by the channel.
    ignore_changes = [
      default_node_pool[0].node_count,
      kubernetes_version,
    ]
  }

  depends_on = [azurerm_role_assignment.network]
}

# Separate user node pool so application pods never land on system nodes.
resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count = var.user_node_pool_enabled ? 1 : 0

  name                    = "user"
  kubernetes_cluster_id   = azurerm_kubernetes_cluster.this.id
  vm_size                 = var.user_node_vm_size
  vnet_subnet_id          = var.subnet_id
  zones                   = var.availability_zones
  auto_scaling_enabled    = true
  min_count               = var.user_node_min_count
  max_count               = var.user_node_max_count
  max_pods                = 50
  mode                    = "User"
  host_encryption_enabled = var.host_encryption_enabled
  tags                    = var.tags

  upgrade_settings {
    max_surge = "33%"
  }

  lifecycle {
    ignore_changes = [node_count]
  }
}

# Lets the CSI driver read secrets from the landing zone Key Vault.
resource "azurerm_role_assignment" "kv_secrets_user" {
  count = var.key_vault_access_enabled ? 1 : 0

  scope                = var.key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.this.key_vault_secrets_provider[0].secret_identity[0].object_id
}

resource "azurerm_monitor_diagnostic_setting" "this" {
  name                           = "diag-to-law"
  target_resource_id             = azurerm_kubernetes_cluster.this.id
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  dynamic "enabled_log" {
    for_each = ["kube-apiserver", "kube-audit-admin", "kube-controller-manager", "cluster-autoscaler", "guard"]
    content {
      category = enabled_log.value
    }
  }

  enabled_metric {
    category = "AllMetrics"
  }
}
