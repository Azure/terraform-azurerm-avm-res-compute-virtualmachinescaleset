# A Default Virtual Machine Scale Set Deployment 

This example demonstrates a standard deployment of VMSS aligned with reliability recommendations from the [Well Architected Framework](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal).

- a Linux VM
- a virtual network with a subnet
- a public IP associated to the NAT gateway
- a NAT gateway
- an SSH key
- locking code (commented out)
- a health extension
- autoscale
- availability zones
