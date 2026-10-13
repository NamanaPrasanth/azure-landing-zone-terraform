# Azure Kubernetes Service

Hardened AKS cluster for the workload spoke.

- **Entra ID + Azure RBAC only**: local accounts disabled
- **Azure CNI Overlay** with Azure network policy
- **Egress through the hub firewall** (`outbound_type = userDefinedRouting`). The control-plane identity is a user-assigned identity granted `Network Contributor` on the subnet and route table *before* the cluster is created
- System and user node pools across availability zones, with autoscaling, ephemeral OS disks and encryption at host
- **Container Insights** (Azure Monitor agent with managed identity auth) and control-plane logs to Log Analytics
- **Key Vault CSI driver** with secret rotation; its identity gets `Key Vault Secrets User`
- **Workload Identity**, OIDC issuer, Azure Policy add-on
- Automatic patch upgrades and node image updates in a weekly maintenance window

> `host_encryption_enabled` requires the feature to be registered once per subscription:
> `az feature register --namespace Microsoft.Compute --name EncryptionAtHost`

## Usage

```hcl
module "aks" {
  source = "../../modules/aks"

  name                       = "plz-dev-cus"
  location                   = "centralus"
  resource_group_name        = "rg-plz-dev-cus-workload"
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  admin_group_object_ids     = ["<entra-group-object-id>"]
  subnet_id                  = module.spoke.subnet_ids["aks"]
  log_analytics_workspace_id = module.log_analytics.workspace_id
  key_vault_id               = module.key_vault.id

  network_contributor_scopes = {
    subnet      = module.spoke.subnet_ids["aks"]
    route_table = module.spoke.route_table_id
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
| [azurerm_kubernetes_cluster.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_kubernetes_cluster_node_pool.user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster_node_pool) | resource |
| [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) | resource |
| [azurerm_role_assignment.kv_secrets_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.network](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.control_plane](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| location | Azure region. | `string` | n/a | yes |
| log\_analytics\_workspace\_id | Workspace for Container Insights and control plane logs. | `string` | n/a | yes |
| name | Base name (cluster becomes aks-<name>). | `string` | n/a | yes |
| resource\_group\_name | Resource group for the cluster. | `string` | n/a | yes |
| subnet\_id | Subnet for AKS nodes. | `string` | n/a | yes |
| tenant\_id | Microsoft Entra tenant ID for cluster authentication. | `string` | n/a | yes |
| admin\_group\_object\_ids | Entra ID group object IDs granted cluster-admin. | `list(string)` | `[]` | no |
| api\_server\_authorized\_ip\_ranges | Public CIDRs allowed to reach a public API server. Empty = open (use private\_cluster\_enabled in production). | `list(string)` | `[]` | no |
| availability\_zones | Zones for node pools. | `list(string)` | <pre>[<br/>  "1",<br/>  "2",<br/>  "3"<br/>]</pre> | no |
| dns\_service\_ip | CoreDNS service IP, must be inside service\_cidr. | `string` | `"172.16.0.10"` | no |
| host\_encryption\_enabled | Encrypt temp disks and caches at the VM host. Needs the Microsoft.Compute/EncryptionAtHost feature registered. | `bool` | `true` | no |
| key\_vault\_access\_enabled | Grant the CSI driver identity Key Vault Secrets User on key\_vault\_id. | `bool` | `true` | no |
| key\_vault\_id | Key Vault the CSI driver may read secrets from. | `string` | `null` | no |
| kubernetes\_version | Kubernetes version. Null = AKS default; patch upgrades are automatic. | `string` | `null` | no |
| network\_contributor\_scopes | Map of static key => resource ID (subnet, route table) where the control plane gets Network Contributor. | `map(string)` | `{}` | no |
| outbound\_type | userDefinedRouting (egress via firewall) or loadBalancer. | `string` | `"userDefinedRouting"` | no |
| pod\_cidr | Overlay pod CIDR (not routable outside the cluster). | `string` | `"192.168.0.0/16"` | no |
| private\_cluster\_enabled | Private API server. Requires a jump host or build agent inside the network. | `bool` | `false` | no |
| service\_cidr | Kubernetes service CIDR. | `string` | `"172.16.0.0/16"` | no |
| sku\_tier | Free, Standard (uptime SLA) or Premium. | `string` | `"Standard"` | no |
| system\_node\_max\_count | Maximum system nodes. | `number` | `3` | no |
| system\_node\_min\_count | Minimum system nodes. | `number` | `2` | no |
| system\_node\_vm\_size | VM size for the system pool. | `string` | `"Standard_D4ds_v5"` | no |
| tags | Tags applied to every resource. | `map(string)` | `{}` | no |
| user\_node\_max\_count | Maximum user nodes. | `number` | `5` | no |
| user\_node\_min\_count | Minimum user nodes. | `number` | `1` | no |
| user\_node\_pool\_enabled | Create a separate user node pool for workloads. | `bool` | `true` | no |
| user\_node\_vm\_size | VM size for the user pool. | `string` | `"Standard_D4ds_v5"` | no |

## Outputs

| Name | Description |
|------|-------------|
| id | AKS cluster ID. |
| kubelet\_identity\_object\_id | Kubelet identity object ID (grant AcrPull to this). |
| name | AKS cluster name. |
| node\_resource\_group | Auto-generated resource group holding the node VMSS. |
| oidc\_issuer\_url | OIDC issuer URL for Workload Identity federated credentials. |
<!-- END_TF_DOCS -->
