#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# Creates an Entra ID app registration with federated credentials so GitHub
# Actions can log in to Azure using OIDC - no client secret is stored anywhere.
#
#   ./scripts/setup-github-oidc.sh <subscription-id> <github-owner/repo>
# -----------------------------------------------------------------------------
set -euo pipefail

SUBSCRIPTION_ID="${1:?usage: $0 <subscription-id> <owner/repo>}"
REPO="${2:?usage: $0 <subscription-id> <owner/repo>}"
APP_NAME="gh-oidc-azure-landing-zone"

az account set --subscription "$SUBSCRIPTION_ID"
TENANT_ID=$(az account show --query tenantId -o tsv)

APP_ID=$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)
SP_ID=$(az ad sp create --id "$APP_ID" --query id -o tsv)

for SUBJECT in "repo:${REPO}:pull_request" "repo:${REPO}:ref:refs/heads/main" "repo:${REPO}:environment:dev"; do
  NAME=$(echo "$SUBJECT" | tr ':/' '--')
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"${NAME}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"${SUBJECT}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }" -o none
done

# Contributor to deploy resources, User Access Administrator because the
# landing zone creates role assignments (AKS, Key Vault, Policy identities).
for ROLE in "Contributor" "User Access Administrator"; do
  az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
    --role "$ROLE" --scope "/subscriptions/$SUBSCRIPTION_ID" -o none
done

# Resource Policy Contributor to manage policy definitions and assignments.
az role assignment create --assignee-object-id "$SP_ID" --assignee-principal-type ServicePrincipal \
  --role "Resource Policy Contributor" --scope "/subscriptions/$SUBSCRIPTION_ID" -o none

cat <<OUT

Add these GitHub repository secrets:
  AZURE_CLIENT_ID       = $APP_ID
  AZURE_TENANT_ID       = $TENANT_ID
  AZURE_SUBSCRIPTION_ID = $SUBSCRIPTION_ID

And these repository variables:
  AZURE_PLAN_ENABLED      = true
  TFSTATE_RESOURCE_GROUP  = rg-tfstate
  TFSTATE_STORAGE_ACCOUNT = <name printed by bootstrap-state.sh>
  TF_OWNER                = platform-team
  TF_COST_CENTER          = IT-1001

Also grant the app "Storage Blob Data Contributor" on the state storage account.
OUT
