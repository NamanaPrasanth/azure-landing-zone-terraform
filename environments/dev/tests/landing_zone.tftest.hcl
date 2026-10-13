# =============================================================================
# Unit tests for the dev landing zone.
# The azurerm provider is mocked, so these run in CI without any Azure
# credentials and cost nothing. Run with: terraform test
# =============================================================================

mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "11111111-1111-1111-1111-111111111111"
      object_id       = "22222222-2222-2222-2222-222222222222"
      subscription_id = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azurerm_policy_definition" {
    defaults = {
      id = "/providers/Microsoft.Authorization/policyDefinitions/00000000-0000-0000-0000-000000000001"
    }
  }


}

# The random suffix is mocked during plan so the Key Vault name is known and
# can be asserted (override_during requires Terraform >= 1.11).
mock_provider "random" {
  override_during = plan

  mock_resource "random_string" {
    defaults = {
      result = "ab12"
    }
  }
}

variables {
  subscription_id = "00000000-0000-0000-0000-000000000000"
  owner           = "platform-team"
  cost_center     = "IT-1001"
}

# -----------------------------------------------------------------------------
run "default_landing_zone" {
  command = plan

  assert {
    condition     = module.aks[0].name == "aks-plz-dev-cus"
    error_message = "AKS name must follow the aks-<prefix>-<env>-<region> convention."
  }

  assert {
    condition     = module.key_vault.name == "kv-plz-dev-cus-ab12" && length(module.key_vault.name) <= 24
    error_message = "Key Vault name must follow convention and fit Azure's 24-character limit."
  }

  assert {
    condition     = length(module.spoke.route_table_associations) == 2
    error_message = "aks and app subnets route via firewall; the private-endpoints subnet must not."
  }

  assert {
    condition     = alltrue([for k in ["Environment", "Owner", "CostCenter"] : contains(keys(azurerm_resource_group.workload.tags), k)])
    error_message = "Resource groups must carry every tag the Azure Policy baseline requires."
  }

  assert {
    condition     = length(module.monitoring.metric_alert_ids) == 2
    error_message = "Firewall health and AKS CPU metric alerts should both exist."
  }
}

# -----------------------------------------------------------------------------
run "cost_saving_mode" {
  command = plan

  variables {
    firewall_enabled = false
    aks_enabled      = false
    sentinel_enabled = false
  }

  assert {
    condition     = output.firewall_private_ip == null
    error_message = "No firewall should be deployed in cost-saving mode."
  }

  assert {
    condition     = length(module.spoke.route_table_associations) == 0
    error_message = "No subnet should be routed to a firewall that does not exist."
  }

  assert {
    condition     = output.aks_cluster_name == null
    error_message = "AKS must be skipped when aks_enabled is false."
  }

  assert {
    condition     = length(module.monitoring.metric_alert_ids) == 0
    error_message = "Metric alerts for absent resources must not be created."
  }

  assert {
    condition     = length(module.log_analytics.sentinel_rule_ids) == 0
    error_message = "Sentinel rules must be skipped when Sentinel is disabled."
  }
}

# -----------------------------------------------------------------------------
run "rejects_bad_prefix" {
  command = plan

  variables {
    prefix = "Contoso-Prod"
  }

  expect_failures = [var.prefix]
}
