param([string]$BackupDirectory='')
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'common.ps1')
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'backup.ps1')
$lock=$null
try {
    Assert-Guest
    Assert-BackupStorage
    $lock=Enter-TransactionLock
    if (!$BackupDirectory) {
        Get-ChildItem -LiteralPath (Join-Path $script:ToolkitRoot 'backups') | Where-Object {$_.PSIsContainer} | Select-Object FullName
        $BackupDirectory=Read-Host 'Full backup directory to restore (blank cancels)'
    }
    if (!$BackupDirectory) { exit 0 }
    $BackupDirectory=[IO.Path]::GetFullPath($BackupDirectory)
    Assert-BackupStorage $BackupDirectory
    $manifest=Read-ConfigurationBackup $BackupDirectory
    Write-Host ('Restore '+$manifest.Option+' to '+$manifest.Before.Type+' '+$manifest.Before.Value)
    Write-Host 'Only the recorded value/start mode is restored. Logon/boot may be needed for runtime effects.'
    if ((Read-Host 'Type RESTORE to continue') -cne 'RESTORE') { Write-Host 'Cancelled.'; exit 0 }
    Restore-ConfigurationBackup $BackupDirectory
    Write-Host 'Original setting restored and read back successfully.'
    exit 0
} catch { Write-Log ('Restore failed: '+$_.Exception.Message); Write-Host ('ERROR: '+$_.Exception.Message); exit 1 }
finally { if ($null -ne $lock) { $lock.Close() } }
