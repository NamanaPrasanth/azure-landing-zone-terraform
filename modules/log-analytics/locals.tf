locals {
  default_analytics_rules = {
    "privileged-role-assignment" = {
      display_name    = "Privileged role assigned at subscription scope"
      description     = "Detects Owner, Contributor or User Access Administrator role assignments."
      severity        = "High"
      tactics         = ["PrivilegeEscalation", "Persistence"]
      query_frequency = "PT1H"
      query_period    = "PT1H"
      query           = <<-KQL
        AzureActivity
        | where OperationNameValue =~ "Microsoft.Authorization/roleAssignments/write"
        | where ActivityStatusValue =~ "Success"
        | extend RoleDefinitionId = tostring(parse_json(tostring(parse_json(Properties).requestbody)).Properties.RoleDefinitionId)
        | where RoleDefinitionId has_any (
            "8e3af657-a8ff-443c-a75c-2fe8c4bcb635",  // Owner
            "b24988ac-6180-42a0-ab88-20f7382dd24c",  // Contributor
            "18d7d88d-d35e-4fb5-a5c3-7773c20a72d9")  // User Access Administrator
        | project TimeGenerated, Caller, CallerIpAddress, ResourceGroup, RoleDefinitionId, _ResourceId
      KQL
    }

    "key-vault-deleted" = {
      display_name    = "Key Vault deleted"
      description     = "Detects deletion of any Key Vault in the subscription."
      severity        = "Medium"
      tactics         = ["Impact"]
      query_frequency = "PT1H"
      query_period    = "PT1H"
      query           = <<-KQL
        AzureActivity
        | where OperationNameValue =~ "Microsoft.KeyVault/vaults/delete"
        | where ActivityStatusValue =~ "Success"
        | project TimeGenerated, Caller, CallerIpAddress, ResourceGroup, _ResourceId
      KQL
    }

    "nsg-rule-changed" = {
      display_name    = "Network security group rule created or modified"
      description     = "Surfaces NSG rule changes for review."
      severity        = "Low"
      tactics         = ["DefenseEvasion"]
      query_frequency = "PT1H"
      query_period    = "PT1H"
      query           = <<-KQL
        AzureActivity
        | where OperationNameValue =~ "Microsoft.Network/networkSecurityGroups/securityRules/write"
        | where ActivityStatusValue =~ "Success"
        | project TimeGenerated, Caller, CallerIpAddress, ResourceGroup, _ResourceId
      KQL
    }
  }

  analytics_rules = merge(local.default_analytics_rules, var.extra_analytics_rules)

  saved_searches = {
    "firewall-denied-traffic" = {
      display_name = "Azure Firewall - denied flows (last 24h)"
      query        = <<-KQL
        union AZFWNetworkRule, AZFWApplicationRule
        | where TimeGenerated > ago(24h)
        | where Action == "Deny"
        | summarize Hits = count() by SourceIp, DestinationIp = coalesce(DestinationIp, Fqdn), DestinationPort, Protocol
        | order by Hits desc
      KQL
    }

    "key-vault-access-failures" = {
      display_name = "Key Vault - failed or forbidden requests"
      query        = <<-KQL
        AzureDiagnostics
        | where ResourceProvider == "MICROSOFT.KEYVAULT"
        | where httpStatusCode_d >= 400
        | summarize Failures = count() by Resource, OperationName, CallerIPAddress, httpStatusCode_d
        | order by Failures desc
      KQL
    }

    "aks-pod-restarts" = {
      display_name = "AKS - containers restarting"
      query        = <<-KQL
        KubePodInventory
        | where TimeGenerated > ago(1h)
        | where ContainerRestartCount > 0
        | summarize Restarts = max(ContainerRestartCount) by Namespace, Name, ContainerName
        | order by Restarts desc
      KQL
    }

    "resource-changes-by-caller" = {
      display_name = "Activity Log - write/delete operations by caller"
      query        = <<-KQL
        AzureActivity
        | where TimeGenerated > ago(7d)
        | where OperationNameValue endswith "/write" or OperationNameValue endswith "/delete"
        | where ActivityStatusValue =~ "Success"
        | summarize Operations = count() by Caller, ResourceGroup
        | order by Operations desc
      KQL
    }
  }
}
