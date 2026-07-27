# Virtual Machine Scale Set with an extension using protected settings (Windows)

This example demonstrates a Windows VMSS where an extension is configured with
**protected settings** (`extension_protected_setting`), alongside other
extensions that only use public settings. The deployment includes:

- a Windows VMSS
- a virtual network with a subnet
- a NAT gateway with an associated public IP
- a VMAccess extension whose admin `Password` is delivered via
  `protectedSettings` (encrypted / write-only)
- a BGInfo extension using only public settings
- an Application Health extension that TCP-probes the WinRM port, supplying
  the health signal Azure requires to enable automatic instance repair

It is also the regression scenario for issue #159: because the VMAccess
extension carries a protected setting, the module builds the extensions array in
both `body` and `sensitive_body`. The azapi provider merges `sensitive_body`
over `body` with RFC 7396 JSON Merge Patch (arrays are replaced wholesale), so
the module must mirror every non-sensitive property into `sensitive_body`;
otherwise the extensions would be provisioned with empty properties and the
post-apply idempotency check would fail.
