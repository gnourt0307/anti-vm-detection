# Windows 11 host and VMware Workstation experiments

Guest scripts cannot modify host CPUID presentation, SMBIOS, ACPI, virtual PCI identities or disk-controller firmware. This host module deliberately audits without applying VMX changes. The guest's two integration settings are separately backed up by its own scripts.

## Record and audit

Record Workstation's exact version/build from Help > About, virtual hardware compatibility level, guest edition/service pack/bitness, firmware type, VMware Tools version and guest SHA-2 patch status. Do not infer Workstation guest support just because a VM boots. Confirm the installed Workstation release's compatibility guide and Tools release notes.

Fully shut down the guest, close its console and take a snapshot or independent VM backup. A suspend state is not a powered-off baseline. Save the current VM settings and a copy of the VMX outside the VM directory. Preserve the complete VM configuration/disk set if experimenting with controllers or virtual hardware versions.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\host\vmware_config_audit.ps1 -VmxPath 'D:\VMs\Win7Lab\Win7Lab.vmx'
```

The audit reports relevant explicit keys, duplicate keys, unknown lines, VMX SHA-256 and nearby lock entries. A lock is only a caution; stale locks exist and their absence does not prove shutdown. Missing VMX keys mean default behavior is unknown, not disabled. The audit does not execute VMX content or write to the VM directory. It cannot determine effective settings inherited from the VMware release or host defaults. It does not discover unrelated VMs.

## Documented settings to evaluate manually

Use the installed version's Workstation UI and record old/new values. UI availability and naming vary. This table describes experiments, not a preset:

| Setting | UI and action | Consequence | Reverse and validate |
|---|---|---|---|
| Shared folders | VM Settings > Options > Shared Folders: disable unneeded shares | Host-folder access stops; guest HGFS driver/artifacts may remain | Restore original sharing choice; test access and compare inventory |
| Copy/paste and drag/drop | Options > Guest Isolation: uncheck the relevant integration features | Cross-boundary clipboard/drag/drop stops; Tools can remain installed | Restore original checkboxes; test each direction with harmless text/file |
| Processor topology | Hardware > Processors: select supported processor/core counts | Changes exposed topology, scheduling and possible OS edition limits | Restore saved counts while powered off; compare CPUID/WMI/Windows counts |
| Memory | Hardware > Memory: use resources appropriate to the actual test workload | Changes memory pressure and performance; no inherent proof of a physical machine | Restore original allocation; repeat timing tests under matching load |

These UI features are described in the [Workstation Pro 17 guide](https://techdocs2-prod.adobecqms.net/content/dam/broadcom/techdocs/us/en/pdf/vmware/desktop-hypervisors/workstation/vmware-workstation-pro-17-0.pdf). This toolkit has not exercised them on the user's Workstation installation.

For graphics compatibility, Hardware > Display exposes **Accelerate 3D graphics**. Record its state and test the legacy application's rendering/performance before and after; keep a compatible guest display driver. Restore the checkbox if performance or functionality regresses. This does not imply VMware adapter identifiers disappear. [Broadcom graphics guidance](https://knowledge.broadcom.com/external/article?legacyId=2021698).

For MAC-address experiments, use Workstation's supported virtual NIC advanced settings and documented address constraints. Record address type and value, check uniqueness on the lab network, and preserve DHCP/static-IP and license dependencies. Do not assign a random physical vendor's identity. Restore the original address/type and validate connectivity. A supported MAC change need not remove VMware OUIs or PCI/device descriptions. [Broadcom hosted-VM MAC guidance](https://knowledge.broadcom.com/external/article?legacyId=507).

Prefer existing working storage/network controllers. Changing them may require preinstalled signed guest drivers, and storage changes can prevent boot. Such migrations and virtual hardware upgrades are outside automatic configuration. Firmware switching is not an identity cleanup operation and can also break boot. Use an independent VM clone and recovery plan for those compatibility experiments.

## VMware Tools compatibility

Broadcom differentiates Windows 7 SP1 with and without the SHA-2 update KB4474419. Its table limits an unpatched Windows 7/SP1 guest to Tools through 11.0.6, while SHA-2-enabled SP1 has a broader range. It also identifies 12.4.x as the last compatible Tools family for supported 32-bit Windows guests. These are separate constraints; verify the exact package's requirements, signing and servicing-stack prerequisites. Do not assume that the newest Tools ISO supports x86 or that 11.0.6 is the universal last version for all Win7 SP1 installations. [Broadcom compatibility table](https://knowledge.broadcom.com/external/article/313371/vmware-tools-compatibility-with-guest-op.html).

Use the Tools installer's supported Modify/Repair controls for optional components. Removing shared-folder support loses HGFS access. Removing optimized NIC/storage/display drivers can harm connectivity, boot or graphics. Stopping the main Tools service can disrupt guest operations, synchronization, shutdown and quiescing; this toolkit leaves it alone. Tools installation/repair may restore startup entries and other metadata, which is legitimate configuration drift requiring a fresh baseline.

## Experiment record

For each run, save: snapshot identifier, Workstation/version, virtual hardware level, Tools/version, exact UI change, original/new setting, UTC time, operator, expected feature change, before/after report paths, observed regression, and reversal result. Change only one setting per experiment. Revert it and confirm the baseline behavior before testing the next. A registry value, process name or OUI disappearing is not evidence that hypervisor-level fingerprints changed.

VMX strings commonly promoted as stealth flags are classified research-only in the audit. This project does not provide an apply recipe for them and does not assume they are supported across Workstation releases.
