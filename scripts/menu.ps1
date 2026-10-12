. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'common.ps1')
function Invoke-Module([string]$Name,[string[]]$Arguments=@()) {
    $path=Join-Path $script:ToolkitRoot ('scripts\'+$Name+'.ps1')
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path @Arguments
    if ($LASTEXITCODE -eq 2) { Write-Warning 'Completed with partial coverage; inspect the report.' }
    elseif ($LASTEXITCODE -ne 0) { Write-Warning ('Operation failed: exit '+$LASTEXITCODE) }
}
function Get-LatestReport {
    $pointer=Join-Path $script:ToolkitRoot 'reports\latest.txt'
    if (!(Test-Path -LiteralPath $pointer)) { throw 'Run a scan first.' }
    $path=[IO.File]::ReadAllText($pointer).Trim()
    if (!(Test-Path -LiteralPath (Join-Path $path 'scan-state.txt'))) { throw 'Latest report incomplete or missing.' }
    return $path
}
Write-Host ('PowerShell '+$PSVersionTable.PSVersion+'; process bits='+([IntPtr]::Size*8)+'; elevated='+(Test-Administrator))
Write-Host 'Read-only diagnostics work on other Windows versions; configuration requires Win7 SP1 x86 VMware.'
while ($true) {
    Write-Host @'
=============================================
 Windows 7 x86 VM Research Toolkit
=============================================
[1] Run Full VM Fingerprint Scan
[2] View Detected Virtualization Indicators
[3] Export Baseline Report (new full scan)
[4] View Supported Configuration Options
[5] Apply Selected Safe Configuration
[6] Compare Before / After Results
[7] Restore Previous Configuration
[8] Export Complete Diagnostic Report Bundle
[9] View System Compatibility
[0] Exit
'@
    $choice=Read-Host 'Select an option'
    try {
        switch ($choice) {
            '1' { Invoke-Module 'inventory' }
            '2' { Get-Content -LiteralPath (Join-Path (Get-LatestReport) 'summary.txt') }
            '3' { Invoke-Module 'inventory' }
            '4' { Get-Options | Format-List; Write-Host ('Host experiments: '+(Join-Path $script:ToolkitRoot 'docs\HOST-GUIDE.md')) }
            '5' { Invoke-Module 'configure' }
            '6' { Invoke-Module 'validate' }
            '7' { Invoke-Module 'rollback' }
            '8' { Invoke-Module 'export-report' }
            '9' {
                $path=Join-Path $script:ToolkitRoot ('reports\compat-'+(Get-Stamp)+'.xml')
                $code=Invoke-NativeScan $path 'compatibility'
                Get-NativeRows $path | Format-Table Id,Value -AutoSize
            }
            '0' { exit 0 }
            default { Write-Host 'Choose 0 through 9.' }
        }
    } catch { Write-Host ('ERROR: '+$_.Exception.Message); Write-Log $_.Exception.Message }
}
