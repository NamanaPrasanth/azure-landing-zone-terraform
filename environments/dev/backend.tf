# Remote state in Azure Storage with blob-lease locking and Entra ID auth.
# Values are supplied at init time so the same code works for every
# environment:
#
#   terraform init -backend-config=backend.hcl
#
# Create the storage account first with scripts/bootstrap-state.sh.
terraform {
  backend "azurerm" {}
}
