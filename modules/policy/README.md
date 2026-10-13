# Azure Policy Governance

Governance guardrails applied at subscription scope.

1. **Custom initiative (policy set)** that bundles built-in policies, looked up by display name so no GUIDs are hard-coded:
   - Allowed locations (resources and resource groups)
   - Required tags on resource groups (one reference per tag)
   - Key Vault deletion protection and storage secure transfer (Audit / Deny switch)
2. **Inherit tag from resource group** (`Modify` effect) with a system-assigned identity and `Tag Contributor` role, so tags flow down automatically during remediation
3. **Custom policy definition** that denies public IP addresses, assigned only to workload resource groups so spokes must egress through the hub firewall

Set `enforce = false` for a report-only first rollout (`DoNotEnforce` mode), review compliance, then switch it on.

## Usage

```hcl
module "policy" {
  source = "../../modules/policy"

  name                     = "plz-dev-cus"
  location                 = "centralus"
  subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
  allowed_locations        = ["centralus", "eastus2"]
  required_tags            = ["Environment", "Owner", "CostCenter"]

  deny_public_ip_resource_group_ids = {
    workload = azurerm_resource_group.workload.id
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
| [azurerm_policy_definition.deny_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_definition) | resource |
| [azurerm_policy_set_definition.baseline](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/policy_set_definition) | resource |
| [azurerm_resource_group_policy_assignment.deny_public_ip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group_policy_assignment) | resource |
| [azurerm_role_assignment.inherit_tag](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_subscription_policy_assignment.baseline](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |
| [azurerm_subscription_policy_assignment.inherit_tag](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subscription_policy_assignment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| allowed\_locations | Regions where resources may be deployed. | `list(string)` | n/a | yes |
| location | Location for policy assignment managed identities. | `string` | n/a | yes |
| name | Prefix for policy definitions and assignments. | `string` | n/a | yes |
| subscription\_resource\_id | Subscription resource ID, e.g. /subscriptions/00000000-0000-0000-0000-000000000000. | `string` | n/a | yes |
| data\_protection\_effect | Effect for Key Vault deletion protection and storage secure transfer (Audit, Deny, Disabled). | `string` | `"Audit"` | no |
| deny\_public\_ip\_resource\_group\_ids | Map of static key => resource group ID where public IPs are denied. | `map(string)` | `{}` | no |
| enforce | false = DoNotEnforce mode (evaluate and report only). Useful for a first rollout. | `bool` | `true` | no |
| inherited\_tags | Tags copied from the resource group onto resources that lack them. | `list(string)` | <pre>[<br/>  "Environment",<br/>  "CostCenter"<br/>]</pre> | no |
| required\_tags | Tags that every resource group must carry. | `list(string)` | <pre>[<br/>  "Environment",<br/>  "Owner",<br/>  "CostCenter"<br/>]</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| baseline\_assignment\_id | ID of the subscription-level baseline assignment. |
| baseline\_initiative\_id | ID of the landing zone baseline initiative. |
| deny\_public\_ip\_definition\_id | ID of the custom deny-public-IP policy definition. |
<!-- END_TF_DOCS -->
