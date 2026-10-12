# Dot-source only. A backup is created by configure.ps1 after explicit consent.
function New-ConfigurationBackup([string]$Option,$Before,$After,[string]$Baseline,[string]$Directory) {
    $definition=Get-OptionDefinition $Option
    if (!(Test-Path -LiteralPath $Baseline)) { throw 'A native baseline is required.' }
    $baselineDoc=Read-SafeXml $Baseline
    if ($baselineDoc.report.complete -ne 'true') { throw 'Baseline is incomplete; resolve collection errors before applying changes.' }
    $export=Join-Path $Directory 'registry-before.reg'
    & reg.exe export ('HKLM\'+$definition.Path) $export /y | Out-Null
    if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $export)) { throw 'Registry export failed; nothing was changed.' }
    $manifest=New-Record @{ Schema=1; Id=(Split-Path $Directory -Leaf); UTC=(Get-Date).ToUniversalTime().ToString('o'); Machine=(Get-MachineIdentity); Option=$Option; Before=$Before; After=$After; BaselineHash=(Get-Sha256 $Baseline); RegistryExportHash=(Get-Sha256 $export) }
    $path=Join-Path $Directory 'manifest.clixml'
    $temp=Join-Path $Directory 'manifest-prepared.clixml'
    $manifest | Export-Clixml -Path $temp -Depth 8
    Write-AtomicText $path ([IO.File]::ReadAllText($temp))
    # The manifest is never edited again. journal.txt is the mutable transaction state.
    Write-AtomicText (Join-Path $Directory 'manifest.sha256') (Get-Sha256 $path)
    Write-AtomicText (Join-Path $Directory 'journal.txt') "Prepared`r`nReady for mutation; original state is recoverable."
    return $manifest
}
function Read-ConfigurationBackup([string]$Directory) {
    $path=Join-Path $Directory 'manifest.clixml'
    $hash=[IO.File]::ReadAllText((Join-Path $Directory 'manifest.sha256')).Trim()
    if ($hash -cne (Get-Sha256 $path)) { throw 'Manifest checksum mismatch. Do not restore corrupted or edited backups.' }
    # CLIXML is deserialized data, never dot-sourced or executed. Trust only your own backups.
    $m=Import-Clixml -Path $path
    if ($m.Schema -ne 1 -or $m.Machine -cne (Get-MachineIdentity)) { throw 'Backup schema/machine identity mismatch.' }
    $d=Get-OptionDefinition ([string]$m.Option)
    $expected=Get-DesiredState $m.Option
    if (!(Test-StateEqual $expected $m.After)) { throw 'Manifest contains an unsupported desired state.' }
    if (!$m.Before.Exists) { throw 'Manifest has no original component to restore.' }
    if ($d.Kind -eq 'Registry' -and @('String','ExpandString') -notcontains $m.Before.Type) { throw 'Invalid original registry type.' }
    if ($d.Kind -eq 'Service' -and ($m.Before.Type -ne 'ServiceStart' -or @('2','3','4') -notcontains [string]$m.Before.Value)) { throw 'Invalid original service state.' }
    if ($m.BaselineHash -cne (Get-Sha256 (Join-Path $Directory 'baseline.xml')) -or $m.RegistryExportHash -cne (Get-Sha256 (Join-Path $Directory 'registry-before.reg'))) { throw 'Baseline or registry export checksum mismatch.' }
    return $m
}
function Restore-ConfigurationBackup([string]$Directory) {
    $m=Read-ConfigurationBackup $Directory
    $current=Get-OptionState $m.Option
    if (!(Test-StateEqual $current $m.Before) -and !(Test-StateEqual $current $m.After)) { throw 'Configuration drift detected. Current state is neither original nor toolkit-applied; manual reconciliation required.' }
    Write-AtomicText (Join-Path $Directory 'journal.txt') "Restoring`r`nRetry rollback if interrupted."
    if (!(Test-StateEqual $current $m.Before)) { Set-OptionState $m.Option $m.Before }
    if (!(Test-StateEqual (Get-OptionState $m.Option) $m.Before)) { throw 'Restore readback failed; backup remains pending.' }
    Write-AtomicText (Join-Path $Directory 'journal.txt') ("Restored`r`n"+(Get-Date).ToUniversalTime().ToString('o'))
    Write-Log ('Restored '+$m.Option+' from '+$Directory)
}
