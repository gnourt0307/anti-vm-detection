param([string]$Option='',[switch]$List)
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'common.ps1')
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'backup.ps1')
if ($List) { Get-Options | Format-List; exit 0 }
$lock=$null
$transaction=''
$prepared=$false
try {
    Assert-Guest
    Assert-BackupStorage
    if (!$Option) { Get-Options | Format-List; $Option=Read-Host 'Enter one option ID (blank cancels)' }
    if (!$Option) { exit 0 }
    $definition=Get-OptionDefinition $Option
    $lock=Enter-TransactionLock
    Assert-NoPendingTransaction
    $before=Get-OptionState $Option; $after=Get-DesiredState $Option
    if (!$before.Exists) { throw 'Component absent; no configuration experiment is applicable.' }
    if (Test-StateEqual $before $after) { Write-Host 'Already in the requested state; nothing changed.'; exit 0 }
    Get-Options | Where-Object {$_.Id -eq $Option} | Format-List
    Write-Host ('Original: '+$before.Type+' '+$before.Value)
    Write-Host ('Requested: '+$after.Type+' '+$after.Value)
    Write-Host 'Take a VMware snapshot first. Rollback restores settings, not unsaved application work.'
    if ((Read-Host 'Type APPLY to save a baseline and apply this one change') -cne 'APPLY') { Write-Host 'Cancelled.'; exit 0 }
    $transaction=Join-Path $script:ToolkitRoot ('backups\'+(Get-Stamp))
    New-Item -ItemType Directory -Path $transaction | Out-Null
    # Backup contains startup command lines; restrict to this user, Administrators and SYSTEM.
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    foreach ($sid in @([Security.Principal.WindowsIdentity]::GetCurrent().User,(New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')),(New-Object Security.Principal.SecurityIdentifier('S-1-5-18')))) {
        $rule=New-Object Security.AccessControl.FileSystemAccessRule($sid,'FullControl','ContainerInherit, ObjectInherit','None','Allow')
        $acl.AddAccessRule($rule)
    }
    [IO.Directory]::SetAccessControl($transaction,$acl)
    $baseline=Join-Path $transaction 'baseline.xml'
    $code=Invoke-NativeScan $baseline
    if ($code -ne 0) { throw 'Native baseline incomplete; no change applied.' }
    if (!(Test-StateEqual (Get-OptionState $Option) $before)) { throw 'Configuration changed while scanning; retry from a fresh baseline.' }
    $manifest=New-ConfigurationBackup $Option $before $after $baseline $transaction
    $prepared=$true
    if (!(Test-StateEqual (Get-OptionState $Option) $before)) { throw 'Configuration changed during backup; no mutation attempted.' }
    Set-OptionState $Option $after
    if (!(Test-StateEqual (Get-OptionState $Option) $after)) { throw 'Apply readback failed.' }
    Write-AtomicText (Join-Path $transaction 'journal.txt') ("Applied`r`n"+(Get-Date).ToUniversalTime().ToString('o'))
    Write-Log ('Applied '+$Option+' backup='+$transaction)
    Write-Host ('Applied and verified. Backup: '+$transaction)
    Write-Host 'Run a post-change scan now and again after the documented logon/boot boundary.'
    exit 0
} catch {
    $failure=$_.Exception.Message
    if ($prepared) {
        try { Restore-ConfigurationBackup $transaction; Write-Warning 'Apply failed; original configuration was restored and verified.' }
        catch { Write-Warning ('Recovery pending at '+$transaction+': '+$_.Exception.Message) }
    }
    Write-Log ('Apply failed: '+$failure)
    Write-Host ('ERROR: '+$failure)
    exit 1
} finally { if ($null -ne $lock) { $lock.Close() } }
