# terraform-azurerm-avm-res-compute-virtualmachinescaleset

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. A module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to https://semver.org/

> Note: This AVM will only deploy Azure Virtual Machine Scale Sets in Orchestrated mode.  Please see this reliability guidance for more information:  [Deploy VMs with flexible orchestration mode](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#-deploy-vms-with-flexible-orchestration-mode)

## Credential generating

**Warning:** When using this module with `var.generate_admin_password_or_ssh_key = true`, Terraform might automatically generate an admin password or SSH private key. These generated credentials will be stored in plaintext within your Terraform state file. Ensure that your Terraform state file is securely stored and access is strictly controlled to prevent unauthorized access to sensitive credentials. Consider using remote state storage with encryption and strict access policies, such as Azure Storage with encryption enabled, to mitigate security risks.

Converting such generated credentials as ephemeral is on our roadmap.
