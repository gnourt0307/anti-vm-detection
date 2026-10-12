# Architecture

The native x86 executable is read-only. Independent modules produce XML observations with stable IDs, category, origin, status, evidence, supported option, required privileges, reboot implications and side effects. A failed API is an error or unsupported observation, never a negative detection. XML is UTF-8 and is consumable using .NET 2.0 without JSON dependencies. Scans write a temporary file and atomically publish a new report; existing reports are never overwritten.

PowerShell 2.0 orchestrates the engine, collects WMI with per-query timeouts, emits CLIXML/CSV/HTML, and compares stable IDs. Unknown coverage remains unknown in comparisons. The C++ engine does not invoke PowerShell and works independently. WMI is a separate module because Windows ships the necessary automation support; no COM helper or scripting runtime is bundled into the EXE.

The guest configuration allowlist contains only (1) removal of the VMware User Process Run value, affecting subsequent logons, and (2) setting VGAuthService to demand start without stopping it. Both require an actual Win7 SP1 x86 VMware guest, elevation, an explicit confirmation, and a complete fresh native baseline. No arbitrary registry path or service name is accepted. There is no unattended apply mode.

Transactions: lock -> compatibility -> scan -> inspect current state -> confirm -> registry export -> immutable CLIXML manifest + SHA-256 -> journal Prepared -> mutation -> readback -> journal Applied. Rollback validates the hash, computer identity and allowlist; accepts only current state equal to original or intended state; restores only the specific value/start mode; reads back; marks Restored. A Prepared transaction can be rolled back after interruption. Pending transactions block another apply. Full registry exports are for manual disaster recovery, never blindly imported. Hashes detect corruption, not malicious tampering by an administrator.

Host audit reads an explicitly supplied VMX and reports observed settings, duplicate entries and relevant lock directories. It never modifies VMX. Supported hardware/integration experiments are performed manually through Workstation settings on a powered-off, snapshotted VM; the guide records how to reverse each. Guest rollback cannot restore host state.

Build gate: x86 compile-time assertion, WINVER/_WIN32_WINNT 0x0601, PE subsystem 6.1, static compiler libraries, import audit, host smoke tests. Actual Windows 7 SP1/PowerShell 2.0 and Workstation tests remain separate release acceptance gates.
