# Key Vault

Secure secret store for the landing zone.

- **Azure RBAC authorization** (no legacy access policies)
- **Purge protection** and 90-day soft delete
- **Public network access disabled**; reachable only through a **Private Endpoint** registered in `privatelink.vaultcore.azure.net`
- Role assignments passed in as a map (e.g. `Key Vault Secrets User` for workloads)
- `AuditEvent` logs sent to Log Analytics

## Usage

```hcl
module "key_vault" {
  source = "../../modules/key-vault"

  name                       = "kv-plz-dev-cus-ab12"
  location                   = "centralus"
  resource_group_name        = "rg-plz-dev-cus-security"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  private_endpoint_subnet_id = module.spoke.subnet_ids["private-endpoints"]
  private_dns_zone_id        = azurerm_private_dns_zone.key_vault.id
  log_analytics_workspace_id = module.log_analytics.workspace_id

  role_assignments = {
    app = { role_definition_name = "Key Vault Secrets User", principal_id = "<object-id>" }
  }
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.9.0 |
| azurerm | >= 4.40.0, < 5.0.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | 4.81.0 |

## Resources

| Name | Type |
|------|------|
| [azurerm_key_vault.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_private_endpoint.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) | resource |
| [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Azure region. | `string` | n/a | yes |
| name | Globally unique Key Vault name (3-24 chars, letters, numbers, hyphens). | `string` | n/a | yes |
| resource\_group\_name | Resource group for the vault. | `string` | n/a | yes |
| tenant\_id | Microsoft Entra tenant ID. | `string` | n/a | yes |
| allowed\_ip\_ranges | Public IP ranges allowed through the vault firewall (only used if public access is on). | `list(string)` | `[]` | no |
| diagnostics\_enabled | Send diagnostics to log\_analytics\_workspace\_id. A plain bool keeps count known at plan time. | `bool` | `true` | no |
| log\_analytics\_workspace\_id | Workspace for audit logs. | `string` | `null` | no |
| private\_dns\_zone\_enabled | Register the private endpoint in private\_dns\_zone\_id. | `bool` | `true` | no |
| private\_dns\_zone\_id | ID of the privatelink.vaultcore.azure.net zone. | `string` | `null` | no |
| private\_endpoint\_enabled | Create a private endpoint in private\_endpoint\_subnet\_id. | `bool` | `true` | no |
| private\_endpoint\_subnet\_id | Subnet for the private endpoint. | `string` | `null` | no |
| public\_network\_access\_enabled | Allow public network access. Keep false and use the private endpoint. | `bool` | `false` | no |
| role\_assignments | Map of key => { role\_definition\_name, principal\_id } granted at vault scope. | <pre>map(object({<br/>    role_definition_name = string<br/>    principal_id         = string<br/>  }))</pre> | `{}` | no |
| sku\_name | standard or premium (HSM-backed keys). | `string` | `"standard"` | no |
| soft\_delete\_retention\_days | Soft-delete retention (7-90 days). | `number` | `90` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | Key Vault resource ID. |
| name | Key Vault name. |
| private\_endpoint\_ip | Private IP of the vault's private endpoint. |
| vault\_uri | Key Vault URI. |
<!-- END_TF_DOCS -->
