# Windows Virtual Machine Scale Set Deployment with auto generated password stored in keyvault.

This configuration example shows the use of an auto-generated password stored in keyvault for Windows VMSS.

- a Windows VM
- a virtual nework with a subnet
- a NAT gateway
- a public IP associated to the NAT gateway
- a randomly generated password
- locking code (commented out)
- a health extension
- autoscale
- availability zones
- A keyvault for storing the password
