# Reproducible validation and release gates

Do not interpret host smoke tests as Windows 7 certification. Run these steps in a disposable, snapshotted VMware Workstation Windows 7 SP1 x86 guest before relying on configuration automation. Record failures and partial reports unchanged.

## Guest preflight

Record `ver`, Windows edition/SP/build, Workstation version, Tools version, virtual hardware compatibility and patch state. In Windows PowerShell run `$PSVersionTable` and `[IntPtr]::Size`; require version **2.0** when testing that compatibility promise and a 4-byte pointer on a native 32-bit OS. Confirm `$env:PROCESSOR_ARCHITEW6432` is empty. A modern host that prints a deprecation message and launches its default engine is not a PS2 test.

Extract the release to local fixed NTFS. Compare the executable's SHA-256 with `SHA256SUMS.txt` using `certutil -hashfile build\vmtool.exe SHA256`, if available, or the .NET `Get-Sha256` helper. Run `build\vmtool.exe --help`. Failure to load any DLL/entry point blocks release. No developer software should be installed in the guest.

## Scan and report tests

1. Run `run.bat` unelevated. Run each native module independently using a new output path, then the full native scan. Preserve any access-denied errors. Check XML parses and no existing report is overwritten.
2. Run the full inventory. Require all 15 WMI classes to finish, or explicitly document unsupported/failed classes. Check `scan-state.txt`, not just the menu message.
3. Repeat elevated. Compare firmware fields against `msinfo32`, service state against Services, device IDs against Device Manager and WMI using `Get-WmiObject`. Check topology counts against Task Manager and VMware processor settings.
4. Scan twice with no changes. Compare them. Stable IDs should be unchanged; timings/PIDs/runtime state can differ. Every unexplained change needs investigation, not a success claim.
5. Use the same report for before/after comparison. Expect zero changed/unknown rows for a complete report. For a partial report, error rows must remain unknown even in self-comparison.
6. Set `IncludeWmi=false` temporarily, scan, then restore the settings file. Expect explicit unsupported WMI coverage and inventory exit 2. Compare to the complete report; missing WMI data must not become removed indicators.
7. Run with a report path containing spaces and non-ASCII characters; parse UTF-8 native XML. A nonexistent output parent should fail cleanly. Scan a host or a Win7 x64 VM if available; configuration must refuse the non-target platform.

## Reversible configuration tests

For **each** applicable option separately, after a fresh snapshot:

1. Record the original Run value/type or service start mode/running state. If absent, expect the option to refuse safely. If already desired, expect no-op. For delayed auto-start VGAuth, expect refusal.
2. Choose apply and cancel once. Confirm the setting was untouched.
3. Apply with `APPLY`. Require complete `baseline.xml`, registry export, manifest/hash and journal before accepting the result. Compare hashes with the recorded manifest. Inspect directory permissions with `icacls`.
4. Confirm exact immediate state (Run value absent, or VGAuth Manual with its prior running state unchanged). Check no other Run values/services changed.
5. Scan immediately and after the documented logon/boot boundary. Test clipboard, drag/drop, host-folder access, network, storage, graphics, guest authentication/automation as relevant. Document remaining firmware/CPUID/driver evidence.
6. Attempt another apply before restoring. Expect the pending-transaction guard.
7. Roll back, verify exact original type/value or start mode, rescan after logon/boot and recheck functionality. Repeat rollback; it should be idempotent.

## Failure-injection tests (disposable snapshot only)

The checked-in workflow tests simulate interruption and corruption without modifying system settings. For real integration acceptance, run under a debugger or a **test copy** with explicit pause points inserted after journal Prepared and after mutation. Terminate the process at each pause, then roll back using the untouched production script. The original setting must return in both cases. Do not edit the manifest to simulate interruption.

Also test: non-elevated apply refusal; two concurrent toolkit processes (exclusive lock); a changed unrelated value left intact; manual drift of the target value/start mode causing refusal; corrupted manifest/baseline hash refusal; disk-full/read-only backup failures before mutation; and restore after an installer changes/removes the component. Restore the VM snapshot after destructive fault injection.

## Host experiment and timing protocol

Audit the same powered-off VMX twice and compare hashes. Confirm the audit never changes file length/time/hash. Use a disposable VMX fixture for duplicate-key/unparsed-line tests. For actual host experiments, record and reverse one supported UI setting at a time using HOST-GUIDE.md. Guest rollback must not be expected to reverse host changes.

For timing, allow guest/host to settle, keep power plan/resource allocation fixed, avoid background jobs, repeat five scans before and after, and save raw samples. Record host CPU contention, VBS/hypervisor layering, migration/suspend and guest uptime. Compare distributions, not a single threshold. The code pins sampling to CPU 0 where permitted and restores affinity. Failure to pin is recorded. No timer-resolution or clock configuration is changed.

Release acceptance requires an actual Win7 SP1 x86 loader pass, PowerShell 2.0 execution pass, complete/understood diagnostics, successful real backup/apply/rollback for each supported option, interruption recovery and functional regression checks. Until then, mark the package **host-tested; target validation pending**.
