param([string]$ScanDirectory='')
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'common.ps1')
try {
    if (!$ScanDirectory) { $ScanDirectory=[IO.File]::ReadAllText((Join-Path $script:ToolkitRoot 'reports\latest.txt')).Trim() }
    if (!(Test-Path -LiteralPath (Join-Path $ScanDirectory 'scan-state.txt'))) { throw 'Select a completed inventory directory.' }
    $dest=Join-Path $script:ToolkitRoot ('reports\export-'+(Get-Stamp))
    New-Item -ItemType Directory -Path $dest | Out-Null
    foreach ($name in @('native.xml','observations.csv','observations.clixml','summary.txt','report.html','scan-state.txt')) {
        Copy-Item -LiteralPath (Join-Path $ScanDirectory $name) -Destination (Join-Path $dest $name)
    }
    Copy-Item -LiteralPath (Join-Path $script:ToolkitRoot 'config\settings.ini') -Destination $dest
    $log=Join-Path $script:ToolkitRoot 'logs\operations.log'
    if (Test-Path -LiteralPath $log) { Copy-Item -LiteralPath $log -Destination $dest }
    $hashes=foreach ($f in @(Get-ChildItem -LiteralPath $dest | Where-Object {!$_.PSIsContainer})) { (Get-Sha256 $f.FullName)+'  '+$f.Name }
    Write-AtomicText (Join-Path $dest 'SHA256SUMS.txt') ($hashes -join "`r`n")
    Write-Host ('Exported portable report folder: '+$dest)
    Write-Host 'Contains machine identifiers and command paths. Review before sharing. Backups are kept separately.'
    Write-Log ('Exported '+$dest)
    exit 0
} catch { Write-Host ('ERROR: '+$_.Exception.Message); exit 1 }
