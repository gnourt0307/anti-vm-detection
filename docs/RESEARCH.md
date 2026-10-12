# Research review (2026-10-12)

This is a source-focused review of selected relevant files, not a full security audit or runtime certification of external projects. Downloaded source was inspected as text and was not executed. No repository implementation was copied into the toolkit. Research downloads stay outside the distributable package. Observed Git tree IDs and SHA-256 of downloaded files are retained locally under `research/`; a tree ID is not necessarily a commit ID.

## VMware-Hidden-Mode

[Repository](https://github.com/at0m-b0mb/VMware-Hidden-Mode), observed main tree `81eb43dc4a5051a058ebd81e324c491d35b1c65f`. Inspected `vmstealth.py`, `clean_guest.ps1`, tree and MIT license.

The [host source](https://github.com/at0m-b0mb/VMware-Hidden-Mode/blob/main/vmstealth.py) edits VMX and offers an audit path, using Python standard-library modules including argparse/pathlib and built-in generic type annotations. Its existence is not validation that each VMX key works on each Workstation release. The [guest source](https://github.com/at0m-b0mb/VMware-Hidden-Mode/blob/main/clean_guest.ps1) includes hardware-description replacement, removal/renaming operations and newer cmdlets such as Remove-NetFirewallRule and scheduled-task creation. Those are substantive incompatibilities with the Win7/PowerShell 2 target, beyond its README's stated Windows 10/11 x64 focus. It also manufactures application/user artifacts, outside this project scope.

Windows 7 x86 support: **not established; guest script is not compatible as-is**. Host Python requirements are separate from guest compatibility. Risks include broken integration/drivers, misleading registry mirrors and destructive cleanup. MIT licensing permits reuse with conditions, but no code is integrated. The useful reference is its inventory of detection surfaces, not its concealment claims or mutation sequence.

## anti-anti-vm-detection-dll

[Repository](https://github.com/rsumner33/anti-anti-vm-detection-dll), observed master tree `7fcb6ff6bbae7f312ed044d4e46c31d0fbf8e7b8`. Inspected `HidingDLL/HidingDLL/main.cpp`, its `.vcxproj`, and repository tree.

The [implementation](https://github.com/rsumner33/anti-anti-vm-detection-dll/blob/master/HidingDLL/HidingDLL/main.cpp) installs MinHook hooks from DllMain and references hard-coded blacklist files. Several hook paths are commented out. File-buffer allocation lacks an added terminator before tokenization, and some non-void hook paths lack a return when input files are unavailable. These are concrete stability concerns.

The [project](https://github.com/rsumner33/anti-anti-vm-detection-dll/blob/master/HidingDLL/HidingDLL/HidingDLL.vcxproj) contains Win32/x64 configurations, v140 and SDK 8.1, with machine-specific MinHook include/library paths. This supports the claimed Win7 x86 *intent*, not a verified working build. Dependencies include MinHook and a Windows C++ toolchain; helper scripts require their own Python/packaging environment. No top-level license grant was found in the inspected tree; do not assume redistribution permission, and review MinHook's own license separately.

Integration: **excluded**. AppInit/injected API hooks contradict the read-only/documented-configuration design. Registry/process/file API surfaces are useful diagnostic research, without reproducing interception.

## Pafish

[Repository](https://github.com/a0rtega/pafish), observed master tree `b497899ff355ea7b9ecc1f5cd34a9fd1def02aec`. Inspected `pafish/cpu.c`, `pafish/vmware.c`, `pafish/Makefile.win`, tree, GPL-3.0 license.

The [CPU checks](https://github.com/a0rtega/pafish/blob/master/pafish/cpu.c) examine CPUID and cycle timing. The [VMware checks](https://github.com/a0rtega/pafish/blob/master/pafish/vmware.c) inspect registry, driver files, adapter strings/MAC OUIs and BIOS through WMI. The [Windows build](https://github.com/a0rtega/pafish/blob/master/pafish/Makefile.win) uses MinGW GCC/windres and Windows import libraries, including IP Helper, SetupAPI, COM and WMI.

These inspected APIs and x86-oriented assembly make Win7 x86 a plausible diagnostic target, but no whole-project build, import audit or guest run was performed. Timing thresholds and historical hard-coded paths can produce false conclusions. GPL obligations would apply to code integration; no code is copied or linked. Practical use is a separately reviewed external diagnostic on a lab snapshot, not a bundled dependency. This toolkit uses its own bounded parsing and documented timing measurements without a detection threshold.

## al-khaser

[Repository](https://github.com/ayoubfaouzi/al-khaser) (the LordNoteworthy URL redirects here), observed master tree `f0e5559073fe02c4f50cc8c3ed8d5b302a6a0659`. Inspected `AntiVM/VMWare.cpp`, `al-khaser.vcxproj`, `pch.h`, tree and GPL-2.0 license.

The [VMware module](https://github.com/ayoubfaouzi/al-khaser/blob/master/al-khaser/AntiVM/VMWare.cpp) covers registry/files, network identifiers, processes, SMBIOS and ACPI. The project contains Win32/x64 configurations, v143 and Windows 10 SDK targeting. These settings do not establish minimum-runtime compatibility. [pch.h](https://github.com/ayoubfaouzi/al-khaser/blob/master/al-khaser/pch.h) includes C++ filesystem plus Windows networking, WMI, SetupAPI, power, shell and licensing libraries. The broader project also contains injection, anti-debugging and anti-dumping modules, so running all modules is materially different from passive inventory.

Windows 7 x86: **not verified** for the inspected revision; requires checking all imports/runtime and actual guest execution. Practical integration is diagnostic concept/reference only. GPL-2.0 code is not bundled or copied; selected external checks would need their own licensing, dependency and stability review. The attempted CheckPointSW URL did not resolve and was not treated as evidence.

## Windows/VMware contracts used

- [Microsoft minimum-target macros](https://learn.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt) and [compiler target support](https://learn.microsoft.com/en-us/cpp/overview/supported-platforms-visual-cpp): macros and static linking alone do not certify compatibility.
- [Firmware table API](https://learn.microsoft.com/en-us/windows/win32/api/sysinfoapi/nf-sysinfoapi-getsystemfirmwaretable): user-mode raw SMBIOS and ACPI reads; table data remains untrusted input.
- [SetupAPI](https://learn.microsoft.com/en-us/windows/win32/api/setupapi/nf-setupapi-setupdigetclassdevsw), [IP Helper](https://learn.microsoft.com/en-us/windows/win32/api/iphlpapi/nf-iphlpapi-getadaptersaddresses), [WMI hardware tasks](https://learn.microsoft.com/en-us/windows/win32/wmisdk/wmi-tasks--computer-hardware): documented enumeration instead of protected-hive editing.
- [Run key contract](https://learn.microsoft.com/en-us/windows/win32/setupapi/run-and-runonce-registry-keys) and [ChangeStartMode](https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/changestartmode-method-in-class-win32-service): supported Windows mechanisms for the two allowlisted experiments. This does not claim VMware recommends disabling those components.
- [High-resolution timer guidance](https://learn.microsoft.com/en-us/windows/win32/sysinfo/acquiring-high-resolution-time-stamps): QPC measurements depend on the environment and should not be converted into a universal VM verdict.
- [VMware Tools compatibility](https://knowledge.broadcom.com/external/article/313371/vmware-tools-compatibility-with-guest-op.html): SHA-2 support and x86 package ceilings are separate checks; see host guide.
