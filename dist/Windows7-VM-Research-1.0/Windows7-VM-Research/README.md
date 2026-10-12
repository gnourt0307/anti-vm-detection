# Windows 7 x86 VMware Research Toolkit

A portable, read-only fingerprint scanner plus two narrowly scoped, reversible guest integration experiments. Develop/build on Windows 11; copy the release directory to Windows 7 SP1 x86. No compiler, Python, third-party PowerShell modules, API hooks or kernel drivers are required in the guest.

**Status:** the x86 executable was compiled with MinGW.org GCC 6.3.0 and ran on the Windows 11 development host. Native tests, workflow tests and host inventory/report tests were run. **Execution on Windows 7 SP1 x86, genuine PowerShell 2.0, and VMware configuration apply/restore remain unverified.** See [test evidence](docs/TEST-RESULTS.md) and the mandatory [guest acceptance procedure](docs/VALIDATION.md). An x86 PE and old API imports are necessary compatibility checks, not a Windows 7 certification.

## Start in the guest

1. Shut down the VM and take a VMware snapshot. Record Workstation, virtual hardware and VMware Tools versions.
2. Copy the extracted `Windows7-VM-Research` directory to a **local NTFS folder**, for example `C:\VMResearch`. Keep the original package. Do not execute transactions from a VMware shared folder, network share, or FAT volume.
3. Run `run.bat`. Non-elevated scans are allowed; denied providers are reported as incomplete. Use **Run as administrator** for complete privileged inventory or configuration experiments.
4. Choose **3** to create an immutable baseline scan directory. Choose **4** to review options. If desired, choose **5**, select one option and type `APPLY` after reviewing the exact current/requested setting.
5. Choose **1** for another scan immediately and again after the documented logon/boot boundary. Choose **6** and enter the before/after directories.
6. Choose **7**, enter the backup directory printed during apply, and type `RESTORE`. Rescan after restoring. Only one pending experiment is allowed; restore it before starting another.
7. Choose **8** to export the latest diagnostic report folder with checksums. Reports contain serial numbers, UUIDs, MAC addresses and local paths; review before sharing.

The launcher uses process-scoped `-ExecutionPolicy Bypass`; it does not persistently change execution policy and does not override organizational policy. Review scripts first. PowerShell must be at least 2.0. The menu reports OS/architecture/elevation; only configuration requires a confirmed Win7 SP1 x86 VMware guest.

## Commands

From the toolkit directory in Windows PowerShell:

```powershell
# Read-only native scan, including independently selectable modules
.\build\vmtool.exe --out .\reports\baseline.xml
.\build\vmtool.exe --out .\reports\cpu.xml --module cpu
.\build\vmtool.exe --help

# Full native + WMI inventory; output directory must not already exist
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\inventory.ps1 -OutputDirectory C:\VMResearch\reports\before
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\inventory.ps1 -OutputDirectory C:\VMResearch\reports\after
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\validate.ps1 -Before C:\VMResearch\reports\before -After C:\VMResearch\reports\after

# These always require interactive consent and validate the target
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure.ps1 -List
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\configure.ps1 -Option tools-user-autostart-off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\rollback.ps1 -BackupDirectory C:\VMResearch\backups\TRANSACTION-ID
```

The native output file must be new; missing parent directories and existing files return exit 1. Native/inventory exit codes: `0` collected successfully, `2` partial coverage, `1` failure. Individual indicator findings do not affect exit status. The consistency module needs other observations; use `--module all` for cross-checks. Isolated consistency runs report insufficient evidence.

## Supported guest changes

| Option | Exact action | Runtime effects and rollback |
|---|---|---|
| `tools-user-autostart-off` | Delete only `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run` value `VMware User Process`, if present as REG_SZ/REG_EXPAND_SZ | Subsequent logon may lose Tools tray, clipboard, drag/drop and user integration. Does not stop a process, service, or driver. Restores the exact unexpanded string and registry type. Does not apply to other startup mechanisms. |
| `vgauth-manual` | Through `Win32_Service.ChangeStartMode`, set existing `VGAuthService` to Manual, without stopping it | Authentication/guest automation may fail at next boot or request. Manual services can still start on demand. Does not uninstall or hide the service. Restore original Auto/Manual/Disabled mode. Delayed automatic start is deliberately refused. |

Both save a complete native baseline, registry export and typed change manifest before mutation. Both verify the setting immediately. A saved setting is not proof of a runtime change. No unattended apply flag exists. No Windows boot, storage, network, graphics or core Tools service is disabled. No identity is fabricated.

## Files and reports

```text
src/, include/     Independent C++ Win32 modules and shared report interface
scripts/           PowerShell 2-compatible guest workflow; host build/audit helpers
host/              Read-only VMware VMX audit
config/            Inventory settings (not a mutation allowlist)
build/vmtool.exe   Compiled x86 engine
reports/           New scan/export/comparison directories; latest.txt pointer
logs/              UTC operation log
backups/           Restricted, machine-bound transaction directories
tests/             Native parser tests and isolated workflow tests
docs/              Architecture, indicator matrix, research, host and validation guides
licenses/          Compiler-runtime notices accompanying the MinGW binary
run.bat            Interactive entry point
```

Each full scan contains `native.xml`, flat `observations.csv`, `observations.clixml`, `report.html`, `summary.txt`, and `scan-state.txt`. XML/CSV carry evidence and provenance; CLIXML preserves PowerShell objects. HTML is a local static report. Summary output includes indicators, inconsistencies and errors. Scan failures never silently become negative findings. Comparisons retain exact values and distinguish changed rows from unknown coverage/enumeration changes. Counts are observation counts, not independent detections or confidence percentages.

Baseline and post-change scans read the same interfaces. They cannot establish that a system is undetectable. Installed driver identities, firmware, CPUID, virtual controllers and other guest-visible behavior can remain unchanged even when an integration option is disabled.

Read [BUILD.md](BUILD.md), [indicator coverage](docs/INDICATORS.md), [host guide](docs/HOST-GUIDE.md), [rollback details](docs/RECOVERY.md), [source research](docs/RESEARCH.md), and [report format](docs/REPORTS.md).
