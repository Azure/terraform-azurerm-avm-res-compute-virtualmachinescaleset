# Hibernation Enabled Virtual Machine Scale Set

This example deploys a Flexible orchestration VMSS with hibernation enabled, and verifies that Azure persisted the capability.

Hibernation pauses a VM by writing the contents of RAM to the OS disk and then deallocating the VM, so you stop paying for compute while keeping the running state. It has to be requested when the scale set is created — the module therefore forces replacement if `hibernation_enabled` is toggled on an existing scale set.

Enabling hibernation is not just a flag. Azure only honours it when the whole configuration supports it, which is what this example demonstrates:

- a VM size that reports the `HibernationSupported` capability — the `sku_selector` helper filters on it
- a supported guest OS — Ubuntu 22.04 LTS
- Flexible orchestration mode — this module is Flexible-only, Uniform does not support hibernation
- a persistent OS disk, so no ephemeral (`diff_disk_settings`) OS disk
- `Regular` priority, since Spot instances cannot hibernate
- the `LinuxHibernateExtension`, which configures the guest OS to suspend to disk

The example also deploys:

- a virtual network with a subnet
- a NAT gateway and public IP, giving the instances the outbound access the extension needs
- an SSH key for the admin user
- an application health extension, which the module requires because it enables `automatic_instance_repair` by default. It probes SSH over TCP, as this example runs no workload for an HTTP probe to reach.

A `postcondition` on the scale set read-back asserts `properties.additionalCapabilities.hibernationEnabled` is `true`, so the deployment fails if Azure ever drops the property instead of silently reporting success.
