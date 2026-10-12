param([Parameter(Mandatory=$true)][string]$VmxPath,[string]$OutputDirectory='')
. (Join-Path (Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent) 'scripts\common.ps1')
try {
    $VmxPath=[IO.Path]::GetFullPath($VmxPath)
    if ([IO.Path]::GetExtension($VmxPath) -ne '.vmx' -or !(Test-Path -LiteralPath $VmxPath -PathType Leaf)) { throw 'Supply an existing .vmx file on the Windows host.' }
    if (!$OutputDirectory) { $OutputDirectory=Join-Path $script:ToolkitRoot ('reports\host-'+(Get-Stamp)) }
    if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a new output directory.' }
    $seen=@{};$rows=New-Object Collections.ArrayList;$lineNumber=0
    foreach ($line in (Get-Content -LiteralPath $VmxPath)) {
        $lineNumber++
        if ($line -match '^\s*([^#\s=]+)\s*=\s*"(.*)"\s*$') {
            $key=$matches[1];$value=$matches[2];$status='observed'
            if ($seen.ContainsKey($key)) { $status='duplicate-key; effective precedence must be checked in Workstation' }
            $seen[$key]=$true
            if ($key -match '^(virtualHW\.version|guestOS|firmware|numvcpus|cpuid\.|memsize|ethernet\d+\.|scsi\d+\.|sata\d+\.|ide\d+\.|svga\.|mks\.|isolation\.|sharedFolder|tools\.|usb|sound\.|vmci|smbios\.|hypervisor\.|monitor_control\.|acpi\.)') {
                $classification='Host-owned; inspect supported Workstation UI'
                if ($key -match '^(cpuid\.|smbios\.|hypervisor\.|monitor_control\.|acpi\.)') { $classification='Research-only override; no support assumption or automatic modification' }
                [void]$rows.Add((New-Record @{Line=$lineNumber;Key=$key;Value=$value;Status=$status;Classification=$classification}))
            }
        } elseif ($line.Trim() -and !$line.Trim().StartsWith('#')) {
            [void]$rows.Add((New-Record @{Line=$lineNumber;Key='unparsed';Value=$line;Status='unknown-syntax';Classification='Inspect manually; file is never rewritten'}))
        }
    }
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $rows | Export-Csv -Path (Join-Path $OutputDirectory 'vmx-audit.csv') -NoTypeInformation -Encoding UTF8
    $rows | ConvertTo-Html -Title 'Read-only VMware configuration audit' | Out-File -FilePath (Join-Path $OutputDirectory 'vmx-audit.html') -Encoding UTF8
    $locks=@(Get-ChildItem -LiteralPath (Split-Path $VmxPath -Parent) | Where-Object {$_.Name -like '*.lck'})
    $meta='VMX SHA256='+(Get-Sha256 $VmxPath)+"`r`nLock entries="+$locks.Count+"`r`nLock presence is a warning, not a definitive power-state check. Missing keys mean defaults are unknown.`r`nNo VMX changes made. See docs/HOST-GUIDE.md."
    Write-AtomicText (Join-Path $OutputDirectory 'audit-state.txt') $meta
    Write-Log ('Host audit: '+$VmxPath+' -> '+$OutputDirectory)
    Write-Host $meta
    Write-Host ('Report: '+$OutputDirectory)
    exit 0
} catch { Write-Host ('ERROR: '+$_.Exception.Message); exit 1 }
