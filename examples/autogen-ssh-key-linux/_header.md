# Linux Virtual Machine Scale Set Deployment with auto generated SSH key stored in keyvault.

This example demonstrates a standard deployment of VMSS aligned with reliability recommendations from the [Well Architected Framework](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal).

**Note: This configuration example shows the use of an auto-generated SSH key stored in keyvault for Linux VMSS.

- a Linux VM
- a virtual network with a subnet
- a NAT gateway
- a public IP associated to the NAT gateway
- a randomly generated SSH key
- locking code (commented out)
- a health extension
- autoscale
- availability zones
- A keyvault for storing the ssh public key
