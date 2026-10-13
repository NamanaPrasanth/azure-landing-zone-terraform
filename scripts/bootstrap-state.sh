#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Creates the Azure Storage account that holds Terraform remote state.
# Run once per subscription, before the first `terraform init`.
#
#   ./scripts/bootstrap-state.sh <subscription-id> [location]
#
# Security settings: TLS 1.2+, no public blob access, no shared-key auth
# (Entra ID only), blob versioning + soft delete for state recovery.
# -----------------------------------------------------------------------------
set -euo pipefail

SUBSCRIPTION_ID="${1:?usage: $0 <subscription-id> [location]}"
LOCATION="${2:-centralus}"
RG="rg-tfstate"
SA="sttfstate$(echo -n "$SUBSCRIPTION_ID" | sha1sum | cut -c1-8)"
CONTAINER="tfstate"

az account set --subscription "$SUBSCRIPTION_ID"
ME=$(az ad signed-in-user show --query id -o tsv)

echo "Creating resource group $RG in $LOCATION"
az group create -n "$RG" -l "$LOCATION" \
  --tags Environment=shared Owner=platform-team CostCenter=platform ManagedBy=bootstrap -o none

echo "Creating storage account $SA"
az storage account create -n "$SA" -g "$RG" -l "$LOCATION" \
  --sku Standard_ZRS --kind StorageV2 \
  --min-tls-version TLS1_2 \
  --allow-blob-public-access false \
  --allow-shared-key-access false \
  --https-only true -o none

az storage account blob-service-properties update -n "$SA" -g "$RG" \
  --enable-versioning true \
  --enable-delete-retention true --delete-retention-days 30 \
  --enable-container-delete-retention true --container-delete-retention-days 30 -o none

SA_ID=$(az storage account show -n "$SA" -g "$RG" --query id -o tsv)
echo "Granting Storage Blob Data Contributor to the signed-in user"
az role assignment create --assignee-object-id "$ME" --assignee-principal-type User \
  --role "Storage Blob Data Contributor" --scope "$SA_ID" -o none

# Role assignments can take a minute to propagate.
sleep 30
az storage container create -n "$CONTAINER" --account-name "$SA" --auth-mode login -o none

cat <<OUT

Remote state ready. Create environments/dev/backend.hcl with:

resource_group_name  = "$RG"
storage_account_name = "$SA"
container_name       = "$CONTAINER"
key                  = "landing-zone/dev.tfstate"
use_azuread_auth     = true
OUT
