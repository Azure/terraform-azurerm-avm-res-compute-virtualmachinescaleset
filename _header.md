# terraform-azurerm-avm-res-compute-virtualmachinescaleset

Major version Zero (0.y.z) is for initial development. Anything MAY change at any time. A module SHOULD NOT be considered stable till at least it is major version one (1.0.0) or greater. Changes will always be via new versions being published and no changes will be made to existing published versions. For more details please go to https://semver.org/

> Note: This AVM will only deploy Azure Virtual Machine Scale Sets in Orchestrated mode.  Please see this reliability guidance for more information:  [Deploy VMs with flexible orchestration mode](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal#-deploy-vms-with-flexible-orchestration-mode)

AzureRM version constrained to less than 4.37 due to issue with underlying provider.  See: [azurerm_orchestrated_virtual_machine_scale_set new variable network_api_version inconsistent plan error](https://github.com/hashicorp/terraform-provider-azurerm/issues/30274)
