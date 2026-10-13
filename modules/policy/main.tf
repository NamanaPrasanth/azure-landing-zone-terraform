# -----------------------------------------------------------------------------
# Azure Policy governance baseline
#   1. A custom initiative (policy set) bundling built-in guardrails,
#      assigned at subscription scope.
#   2. "Inherit tag from resource group" Modify policies with a managed
#      identity so tags flow down automatically.
#   3. A custom "deny public IP" policy assigned to workload resource groups.
# -----------------------------------------------------------------------------

data "azurerm_policy_definition" "allowed_locations" {
  display_name = "Allowed locations"
}

data "azurerm_policy_definition" "allowed_locations_rg" {
  display_name = "Allowed locations for resource groups"
}

data "azurerm_policy_definition" "require_rg_tag" {
  display_name = "Require a tag on resource groups"
}

data "azurerm_policy_definition" "kv_deletion_protection" {
  display_name = "Key vaults should have deletion protection enabled"
}

data "azurerm_policy_definition" "storage_secure_transfer" {
  display_name = "Secure transfer to storage accounts should be enabled"
}

data "azurerm_policy_definition" "inherit_rg_tag" {
  display_name = "Inherit a tag from the resource group if missing"
}

locals {
  # tag name => parameter JSON pointing at that tag's index in the array.
  require_tag_parameters = {
    for idx, tag in var.required_tags :
    tag => jsonencode({ tagName = { value = format("[parameters('requiredTags')[%d]]", idx) } })
  }
}

# --- 1. Landing zone baseline initiative --------------------------------------

resource "azurerm_policy_set_definition" "baseline" {
  name         = "${var.name}-baseline"
  policy_type  = "Custom"
  display_name = "Landing Zone Baseline (${var.name})"
  description  = "Location restrictions, mandatory tags and data-protection guardrails."

  metadata = jsonencode({ category = "Landing Zone", version = "1.0.0" })

  parameters = jsonencode({
    allowedLocations = {
      type     = "Array"
      metadata = { displayName = "Allowed locations", strongType = "location" }
    }
    requiredTags = {
      type     = "Array"
      metadata = { displayName = "Tags required on resource groups" }
    }
    dataProtectionEffect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Audit"
      metadata      = { displayName = "Effect for Key Vault / Storage guardrails" }
    }
  })

  policy_definition_reference {
    reference_id         = "allowedLocations"
    policy_definition_id = data.azurerm_policy_definition.allowed_locations.id
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "allowedLocationsResourceGroups"
    policy_definition_id = data.azurerm_policy_definition.allowed_locations_rg.id
    parameter_values = jsonencode({
      listOfAllowedLocations = { value = "[parameters('allowedLocations')]" }
    })
  }

  # One "require tag" reference per tag, each indexing into requiredTags.
  dynamic "policy_definition_reference" {
    for_each = local.require_tag_parameters
    content {
      reference_id         = "requireRgTag-${policy_definition_reference.key}"
      policy_definition_id = data.azurerm_policy_definition.require_rg_tag.id
      parameter_values     = policy_definition_reference.value
    }
  }

  policy_definition_reference {
    reference_id         = "keyVaultDeletionProtection"
    policy_definition_id = data.azurerm_policy_definition.kv_deletion_protection.id
    parameter_values = jsonencode({
      effect = { value = "[parameters('dataProtectionEffect')]" }
    })
  }

  policy_definition_reference {
    reference_id         = "storageSecureTransfer"
    policy_definition_id = data.azurerm_policy_definition.storage_secure_transfer.id
    parameter_values = jsonencode({
      effect = { value = "[parameters('dataProtectionEffect')]" }
    })
  }
}

resource "azurerm_subscription_policy_assignment" "baseline" {
  name                 = "${var.name}-baseline"
  display_name         = "Landing Zone Baseline"
  subscription_id      = var.subscription_resource_id
  policy_definition_id = azurerm_policy_set_definition.baseline.id
  enforce              = var.enforce

  parameters = jsonencode({
    allowedLocations     = { value = var.allowed_locations }
    requiredTags         = { value = var.required_tags }
    dataProtectionEffect = { value = var.data_protection_effect }
  })

  non_compliance_message {
    content = "This resource violates the landing zone baseline. Check location, required tags and data-protection settings."
  }
}

# --- 2. Inherit tags from the resource group (Modify + remediation identity) --

resource "azurerm_subscription_policy_assignment" "inherit_tag" {
  for_each = toset(var.inherited_tags)

  name                 = substr("${var.name}-inherit-${lower(each.value)}", 0, 64)
  display_name         = "Inherit '${each.value}' tag from resource group"
  subscription_id      = var.subscription_resource_id
  policy_definition_id = data.azurerm_policy_definition.inherit_rg_tag.id
  location             = var.location
  enforce              = var.enforce

  parameters = jsonencode({
    tagName = { value = each.value }
  })

  identity {
    type = "SystemAssigned"
  }
}

# Modify policies need rights to write tags during remediation.
resource "azurerm_role_assignment" "inherit_tag" {
  for_each = azurerm_subscription_policy_assignment.inherit_tag

  scope                = var.subscription_resource_id
  role_definition_name = "Tag Contributor"
  principal_id         = each.value.identity[0].principal_id
}

# --- 3. Custom policy: deny public IPs in workload resource groups ------------

resource "azurerm_policy_definition" "deny_public_ip" {
  name         = "${var.name}-deny-public-ip"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Deny public IP addresses (${var.name})"
  description  = "Workload spokes must egress through the hub firewall, so public IPs are not allowed."

  metadata = jsonencode({ category = "Network", version = "1.0.0" })

  parameters = jsonencode({
    effect = {
      type          = "String"
      allowedValues = ["Audit", "Deny", "Disabled"]
      defaultValue  = "Deny"
      metadata      = { displayName = "Effect" }
    }
  })

  policy_rule = jsonencode({
    "if" = {
      field  = "type"
      equals = "Microsoft.Network/publicIPAddresses"
    }
    "then" = {
      effect = "[parameters('effect')]"
    }
  })
}

resource "azurerm_resource_group_policy_assignment" "deny_public_ip" {
  for_each = var.deny_public_ip_resource_group_ids

  name                 = "deny-public-ip"
  display_name         = "Deny public IP addresses"
  resource_group_id    = each.value
  policy_definition_id = azurerm_policy_definition.deny_public_ip.id
  enforce              = var.enforce

  non_compliance_message {
    content = "Public IPs are not allowed in workload spokes. Route traffic through the hub firewall."
  }
}
