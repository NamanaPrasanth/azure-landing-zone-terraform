provider "azurerm" {
  subscription_id = var.subscription_id

  # Authentication comes from the environment: `az login` locally, or
  # ARM_USE_OIDC / ARM_CLIENT_ID / ARM_TENANT_ID in GitHub Actions.
  storage_use_azuread = true

  features {
    key_vault {
      # Never purge on destroy - purge protection is on anyway.
      purge_soft_delete_on_destroy = false
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
