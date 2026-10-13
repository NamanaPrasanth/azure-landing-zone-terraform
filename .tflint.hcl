config {
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "azurerm" {
  enabled = true
  version = "0.30.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

# prevent_destroy cannot be toggled per environment, and this dev landing zone
# is meant to be torn down after demos. Purge protection (Key Vault) and soft
# delete (Recovery Services vault) still protect the data. Enable this rule
# for production stacks.
rule "azurerm_resources_missing_prevent_destroy" {
  enabled = false
}
