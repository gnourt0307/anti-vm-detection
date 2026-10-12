# Configuration recovery

The native executable never writes system configuration. Guest mutations are limited to the two IDs in `Get-OptionDefinition`. Run apply/restore in a local NTFS copy of the toolkit, elevated, on the intended Win7 SP1 x86 VMware guest. Keep the transaction directory with the VM. Take a VMware snapshot before experimenting.

## Transaction contents

- `baseline.xml`: complete native scan immediately before mutation.
- `registry-before.reg`: export of the relevant Run or VGAuthService key; manual recovery evidence only.
- `manifest.clixml`: schema, UTC timestamp, machine identity (MachineGuid + VM UUID), option, original typed value/start mode, expected new state and baseline/export hashes.
- `manifest.sha256`: corruption check on the immutable manifest.
- `journal.txt`: Prepared, Applied, Restoring, or Restored plus a note/time. Previous versions remain as `.previous-*` evidence.

The toolkit checks elevation and platform before mutation. A process-held exclusive file lock prevents concurrent toolkit apply/restore operations; it releases if the process dies. Another pending manifest blocks apply until restored. A blank or missing journal is treated as pending. Incomplete preparation before the manifest exists cannot have changed the system. The manifest and hashes are durable before the Prepared state and before the setting is changed. Transaction directory ACLs restrict access to the creating account, Administrators and SYSTEM.

If apply fails after preparation, the toolkit tries to restore the original state and reads it back. If that fails, it prints the recovery directory. If interrupted by process termination or power loss, run rollback against that directory even if the journal still says Prepared. Rollback uses measured state rather than assuming the final write occurred. Repeating a successful rollback is harmless.

Rollback refuses corrupted hashes, another machine identity, unexpected option/type/state, missing service structure, or configuration drift. Drift means the setting is neither the original nor the toolkit's expected value. It will not overwrite an unrelated administrator change. There is no force flag. A cloned VM that changed UUID must be handled manually against its own baseline; do not edit identity checks just to make restore pass.

## Manual recovery if automatic rollback refuses

1. Preserve the entire transaction directory and logs. Record the error.
2. Inspect `baseline.xml`, the manifest, `registry-before.reg`, and current state using Registry Editor/Services. Do not import the entire Run export: that could overwrite unrelated startup configuration.
3. For the startup experiment, restore only the saved `VMware User Process` value, using its original REG_SZ or REG_EXPAND_SZ type and exact unexpanded command string. Log off/on to test user integration.
4. For VGAuth, restore its recorded start mode in Services. Automatic=2, Manual=3, Disabled=4 in the backup. No attempt was made to stop/start it, change dependencies or change executable paths. Validate guest authentication/automation after boot.
5. If the VM fails to boot or the experiment extends beyond this toolkit, restore the VMware snapshot or known-good VM backup. Guest rollback cannot undo Workstation hardware changes, restore removed VMware Tools components or recover unsaved application work.

Hashes protect against accidental corruption, not an administrator deliberately rewriting files and hashes. Only restore your own trusted backups. Power-loss safety depends on NTFS/storage honoring write-through and flush operations; a hypervisor snapshot remains the stronger recovery layer. Ordinary SCM/WMI provider operations are not a database transaction, so external administrators and installers should not change these settings concurrently.
