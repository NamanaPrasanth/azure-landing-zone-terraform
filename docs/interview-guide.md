# Walkthrough guide

Notes for presenting this repo: a five-minute walkthrough, what to point at, and the questions it tends to prompt. Deploy it at least once yourself (with `firewall_enabled = false` and `aks_enabled = false` if you want it cheap) so you can describe what you saw in the portal.

## Five-minute walkthrough

1. **Start with the diagram** in the README. "It's a hub-and-spoke landing zone. The hub owns connectivity and egress, the spoke runs workloads, and management and security live in their own resource groups."
2. **Open `environments/dev/main.tf`.** Show that the root module only composes modules: resource groups, then log analytics, hub, spoke, Key Vault, AKS, monitoring, backup, policy.
3. **Pick one module in depth.** `modules/aks/main.tf` is a good choice: user-assigned identity granted Network Contributor before the cluster exists, UDR egress, local accounts disabled, CSI driver identity granted Key Vault Secrets User.
4. **Show governance.** `modules/policy/main.tf`: a custom initiative made of built-ins, a Modify policy with a remediation identity, and a custom deny-public-IP policy scoped to the workload RG.
5. **Show security monitoring.** `modules/log-analytics/locals.tf`: Sentinel rules and saved searches written in KQL.
6. **Finish on the pipeline.** fmt → validate → mocked tests → tflint → checkov → plan via OIDC → gated apply.

## Questions this repo tends to prompt

**Why modules instead of one big configuration?**
Each module has one responsibility and a clear interface (variables in, outputs out). They can be versioned, tested and reused across environments; adding `environments/prod` is a new root module with different variables, not copied code.

**How is state managed?**
Remote state in Azure Storage (`azurerm` backend), with Entra ID auth instead of account keys. The backend uses a blob lease as a lock, so two applies can't run at once. Blob versioning and soft delete allow recovery of a corrupted state file. Backend values are passed at `init` time with `-backend-config` so the same code serves every environment.

**`count` or `for_each`?**
`for_each` with a map whenever there is more than one of something (subnets, alerts, role assignments), because removing an item doesn't shift the indexes of the others. `count` only for on/off toggles. The keys and the count must be known at plan time, which is why this repo uses boolean flags like `private_endpoint_enabled` rather than `count = var.id != null`. The mocked tests caught exactly that bug.

**How do you handle secrets?**
No secrets in code or state where it can be avoided: OIDC for CI, managed identities for Azure services, Key Vault with RBAC for application secrets, and `sensitive = true` on the one secret-like input (the ExpressRoute authorization key). `.tfvars` files are git-ignored.

**Why does AKS depend on the hub and spoke modules?**
With `userDefinedRouting`, nodes bootstrap through the firewall. If the route table or firewall rules aren't in place yet, node provisioning fails, so `depends_on` forces the order.

**How would you roll out Azure Policy safely?**
Assign with `enforce = false` (DoNotEnforce), review the compliance results, fix or exempt, then enforce. For Modify/DeployIfNotExists policies, give the assignment a managed identity with the least role it needs (here, Tag Contributor) and run a remediation task for existing resources.

**How do you detect drift?**
A scheduled `terraform plan` (for example nightly in the pipeline) that fails or alerts when the plan isn't empty. Azure Policy also flags configuration drift on the resources it governs, and the Sentinel rule for NSG changes highlights manual network edits.

**How would you import existing resources?**
Terraform 1.5+ `import` blocks: add the block with the resource ID, run `terraform plan -generate-config-out=generated.tf`, tidy the generated code into the right module, then apply. Plan until it shows no changes.

**What changes for production?**
`private_cluster_enabled = true` (with a build agent in the management subnet), Firewall Premium for IDPS/TLS inspection, `prevent_destroy` lifecycle rules, policy effect `Deny`, customer-managed keys where required, longer log retention, a second region for DR, and protected branches with required reviewers on the `prod` environment.

**How do you test infrastructure code?**
Layers: `fmt` and `validate` for syntax, tflint for provider-specific mistakes, checkov for security misconfiguration, `terraform test` with a mocked provider for logic (naming, conditional resources, input validation), then a real `plan` reviewed on the pull request.

## Commands worth knowing by heart

```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
terraform state list
terraform state show 'module.aks[0].azurerm_kubernetes_cluster.this'
terraform plan -target=module.hub          # only when recovering, not routinely
terraform test
terraform fmt -recursive
terraform providers lock -platform=linux_amd64 -platform=darwin_arm64
```
