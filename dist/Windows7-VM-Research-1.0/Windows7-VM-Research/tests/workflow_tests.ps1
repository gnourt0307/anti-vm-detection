# Uses isolated files and mock registry/service providers. No real system settings change.
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
. (Join-Path $root 'scripts\validate.ps1')
. (Join-Path $root 'scripts\backup.ps1')
$testRoot=Join-Path $root ('reports\workflow-tests-'+(Get-Stamp))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$script:ToolkitRoot=$testRoot
$script:checks=0
function Assert($Condition,[string]$Message) { if (!$Condition) { throw ('FAIL: '+$Message) }; $script:checks++ }
function Expect-Failure([scriptblock]$Action,[string]$Message) {
    $caught=$false;try { & $Action } catch { $caught=$true }
    Assert $caught $Message
}
$o=New-Record @{Id='test';Module='registry';Category='C';Status='indicator';Value='VMware'}
$n=New-Record @{Id='test';Module='registry';Category='C';Status='error';Value='Access denied'}
$d=@(Compare-Observations @($o) @($n));Assert ($d[0].Change -like 'Unknown*') 'Errors are unknown, not removal'
$d=@(Compare-Observations @($o) @());Assert ($d[0].Change -like 'Unknown*') 'Missing rows are unknown'
$d=@(Compare-Observations @($o) @($o));Assert ($d[0].Change -eq 'Unchanged') 'Identical rows unchanged'
$n.Status='absent';$n.Value='Absent';$d=@(Compare-Observations @($o) @($n));Assert ($d[0].Change -eq 'Changed') 'Measured absence is a change'
Expect-Failure { Compare-Observations @($o,$o) @($n) } 'Duplicate IDs rejected'
Expect-Failure { Get-OptionDefinition 'arbitrary-service' } 'Allowlist enforced'
$path=Join-Path $testRoot 'atomic.txt';Write-AtomicText $path 'first';Write-AtomicText $path 'second';Assert ([IO.File]::ReadAllText($path) -eq 'second') 'Atomic replacement works'
$evil=Join-Path $testRoot 'dtd.xml';Write-AtomicText $evil '<!DOCTYPE x [<!ENTITY a SYSTEM "file:///C:/Windows/win.ini">]><x>&a;</x>'
Expect-Failure { Read-SafeXml $evil } 'DTD rejected'
function Get-MachineIdentity { 'mock-machine/mock-uuid' }
$script:fakeState=New-Record @{Exists=$false;Type='Absent';Value=''}
$script:mutations=0
function Get-OptionState([string]$Id) { return $script:fakeState }
function Set-OptionState([string]$Id,$State) { $script:mutations++;$script:fakeState=$State }
$tx=Join-Path $testRoot 'transaction';New-Item -ItemType Directory $tx | Out-Null
$baseline=Join-Path $tx 'baseline.xml';Write-AtomicText $baseline '<report schema="1" complete="true" />'
$reg=Join-Path $tx 'registry-before.reg';Write-AtomicText $reg 'SYNTHETIC TEST DATA - NOT A REGISTRY EXPORT'
$originalState=New-Record @{Exists=$true;Type='ExpandString';Value='%ProgramFiles%\VMware\test.exe'}
$desiredState=Get-DesiredState 'tools-user-autostart-off'
$m=New-Record @{Schema=1;Machine=(Get-MachineIdentity);Option='tools-user-autostart-off';Before=$originalState;After=$desiredState;BaselineHash=(Get-Sha256 $baseline);RegistryExportHash=(Get-Sha256 $reg)}
function Save-TestManifest {
    $m | Export-Clixml -Path (Join-Path $tx 'manifest.clixml') -Depth 8
    Write-AtomicText (Join-Path $tx 'manifest.sha256') (Get-Sha256 (Join-Path $tx 'manifest.clixml'))
}
Save-TestManifest
Write-AtomicText (Join-Path $tx 'journal.txt') 'Prepared'
Restore-ConfigurationBackup $tx
Assert (Test-StateEqual $script:fakeState $originalState) 'Interrupted Prepared transaction restores original typed value'
Assert ($script:mutations -eq 1) 'One mutation during restore'
Restore-ConfigurationBackup $tx
Assert ($script:mutations -eq 1) 'Restore is idempotent'
$script:fakeState=New-Record @{Exists=$true;Type='String';Value='unrelated new command'}
Expect-Failure { Restore-ConfigurationBackup $tx } 'External drift blocks restore'
Assert ($script:mutations -eq 1) 'Drift did not trigger a write'
$m.Machine='wrong-machine';Save-TestManifest
Expect-Failure { Restore-ConfigurationBackup $tx } 'Other-machine backups rejected'
$m.Machine=Get-MachineIdentity;$m.Option='critical-service';Save-TestManifest
Expect-Failure { Restore-ConfigurationBackup $tx } 'Edited allowlist rejected'
$m.Option='tools-user-autostart-off';Save-TestManifest
Add-Content -Path (Join-Path $tx 'manifest.clixml') -Value 'corruption'
Expect-Failure { Restore-ConfigurationBackup $tx } 'Corrupted manifest rejected'
Save-TestManifest
Write-AtomicText $baseline 'corrupted baseline'
Expect-Failure { Restore-ConfigurationBackup $tx } 'Corrupted baseline rejected'
Assert ($script:mutations -eq 1) 'All rejected restores left settings intact'
# Service rollback exercises start-mode preservation, without a real service call.
Write-AtomicText $baseline '<report schema="1" complete="true" />'
$m.BaselineHash=Get-Sha256 $baseline
$m.Option='vgauth-manual'
$m.Before=New-Record @{Exists=$true;Type='ServiceStart';Value='2'}
$m.After=Get-DesiredState 'vgauth-manual'
$script:fakeState=$m.After
Save-TestManifest
Write-AtomicText (Join-Path $tx 'journal.txt') 'Applied'
Restore-ConfigurationBackup $tx
Assert (Test-StateEqual $script:fakeState $m.Before) 'Original service mode restored'
Assert ($script:mutations -eq 2) 'Only one service mutation requested'
$m.Before=New-Record @{Exists=$true;Type='ServiceStart';Value='0'}
Save-TestManifest
Expect-Failure { Restore-ConfigurationBackup $tx } 'Boot-start restore cannot enter allowlist'
$held=Enter-TransactionLock
try { Expect-Failure { Enter-TransactionLock } 'Concurrent transaction lock rejected' } finally { $held.Close() }
$held=Enter-TransactionLock;$held.Close()
Assert $true 'Released lock can be acquired again'
Write-Host ('Workflow tests: '+$script:checks+' checks passed. Fixtures: '+$testRoot)
