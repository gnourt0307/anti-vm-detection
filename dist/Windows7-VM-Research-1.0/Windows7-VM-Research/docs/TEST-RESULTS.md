# Execution evidence

Recorded on 2026-10-12. The available development machine is Windows 11 x64; tests below are host tests unless explicitly identified as simulated. No Windows 7 or VMware guest execution was available.

| Check | Result and scope |
|---|---|
| Compiler | MinGW.org GCC 6.3.0-1, `mingw32`; C++11, `-O2 -Wall -Wextra -Wpedantic -Werror`, static GCC/libstdc++ |
| Native build | Succeeded; `build/vmtool.exe` generated on Windows 11 |
| PE audit | PE32 x86 (machine 0x014c), subsystem 6.1; 154 named imports in 8 descriptors / 7 unique Windows DLLs |
| Dependencies | ADVAPI32, IPHLPAPI, KERNEL32, MSVCRT (two descriptors), SETUPAPI, SHELL32, USER32; no external GCC, libstdc++ or VC runtime DLL |
| Native unit checks | 11 passed: XML escaping/control characters, UTF-8 round trip, marker discrimination, valid SMBIOS strings and malformed lengths/termination, unsupported status |
| Workflow checks | 23 passed against isolated files/mocked state providers: comparison semantics, duplicate rejection, allowlist, atomic replacement, DTD rejection, interrupted restore, idempotence, drift, machine mismatch, corrupted evidence, service mode and concurrent lock handling |
| Native modules | All 11 modules ran individually and together; no collector error in the tested full host scan |
| CLI failure paths | Existing output refused without overwrite; unknown module refused; missing parent directory refused; Unicode/space path accepted |
| WMI inventory | First sandboxed attempt correctly recorded 15 access-denied class failures. Read-only execution outside sandbox collected 8,810 native+WMI rows with NativeExit=0 and WmiErrors=0 at that revision |
| Full inventory artifacts | XML, CSV, CLIXML, HTML, summary and scan-state generated. Atomic latest-pointer replacement was fixed and then tested |
| Comparison/export | Self-comparison of that complete 8,810-row inventory reported zero changes and zero unknown rows; report export with SHA-256 file list succeeded |
| Host VMX audit | Synthetic VMX retained its SHA-256; duplicate key and unknown line correctly reported; no actual Workstation VMX modified |
| PowerShell parsing | Checked-in scripts parsed on installed Windows PowerShell. Guest scripts avoid PS3+ syntax/cmdlets; host packaging/test runner deliberately use PS5 features |
| Real PowerShell 2.0 | **Unverified**. Host `-Version 2.0` emits deprecation/fallback behavior, so it is not evidence of PS2 execution |
| Windows 7 SP1 x86 loader/API runtime | **Unverified**. Source/import/header review and x86 host execution do not replace the target loader test |
| Real guest apply/restore, ACLs, interruption, integration effects | **Unverified**; workflow tests use mock state and do not certify registry/SCM integration on the guest |
| MSVC build | **Unverified**; no MSVC installation was available. Reproduction commands are in BUILD.md |
| Real Workstation UI experiments | **Unverified**; documented manual steps and read-only VMX fixture tests only |

Initial native scans had 2,979 observations; later CPU family/model and feature-consistency rows add two. Counts are tied to the exact report and running host state, not a promised constant. Local evidence remains in `reports/` and `logs/`, including negative-path fixtures. These machine-specific artifacts are intentionally excluded from the transfer package. `build/pe-audit.txt` and `build/compiler.txt` are included; SHA256SUMS identifies the final packaged files.

Run `tests/run-tests.ps1` on Windows 11 to reproduce local tests. Follow every target gate in VALIDATION.md before marking the toolkit verified for a particular Win7/Workstation/Tools combination. Configuration experiments are deliberately not run against the development machine.
