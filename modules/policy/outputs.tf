output "baseline_initiative_id" {
  description = "ID of the landing zone baseline initiative."
  value       = azurerm_policy_set_definition.baseline.id
}

output "baseline_assignment_id" {
  description = "ID of the subscription-level baseline assignment."
  value       = azurerm_subscription_policy_assignment.baseline.id
}

output "deny_public_ip_definition_id" {
  description = "ID of the custom deny-public-IP policy definition."
  value       = azurerm_policy_definition.deny_public_ip.id
}
