# A Default Virtual Machine Scale Set Deployment 

This example demonstrates a standard deployment of VMSS aligned with reliability recommendations from the [Well Architected Framework](https://learn.microsoft.com/en-us/azure/reliability/reliability-virtual-machine-scale-sets?tabs=graph-4%2Cgraph-1%2Cgraph-2%2Cgraph-3%2Cgraph-5%2Cgraph-6%2Cportal).

- a Linux VM
- a virtual network with a subnet
- a NAT gateway
- a public IP associated to the NAT gateway
- an SSH key
- locking code (commented out)
- a health extension
- upgrade mode set to automatic
- autoscale
- availability zones
