param([string]$OutputDirectory='')
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'common.ps1')
try {
    $settings=Get-Settings
    if (!$OutputDirectory) { $OutputDirectory=Join-Path $script:ToolkitRoot ('reports\scan-'+(Get-Stamp)) }
    $OutputDirectory=[IO.Path]::GetFullPath($OutputDirectory)
    if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a new output directory to preserve existing evidence.' }
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $native=Join-Path $OutputDirectory 'native.xml'
    $nativeExit=Invoke-NativeScan $native
    $rows=New-Object Collections.ArrayList
    foreach ($r in @(Get-NativeRows $native)) { [void]$rows.Add($r) }
    $queries=@(
        @('Win32_ComputerSystem','Name','B/K','Manufacturer,Model,NumberOfProcessors,NumberOfLogicalProcessors,TotalPhysicalMemory,SystemType'),
        @('Win32_ComputerSystemProduct','UUID','B','Vendor,Name,Version,IdentifyingNumber,UUID'),
        @('Win32_BIOS','Name','B','Manufacturer,SMBIOSBIOSVersion,SerialNumber,Version,ReleaseDate'),
        @('Win32_BaseBoard','Tag','B','Manufacturer,Product,SerialNumber,Version'),
        @('Win32_Processor','DeviceID','A/K','Name,Manufacturer,ProcessorId,NumberOfCores,NumberOfLogicalProcessors,Architecture,MaxClockSpeed'),
        @('Win32_DiskDrive','DeviceID','F','Model,Manufacturer,SerialNumber,InterfaceType,PNPDeviceID,Size,FirmwareRevision'),
        @('Win32_IDEController','DeviceID','F','Name,Manufacturer,PNPDeviceID,Status'),
        @('Win32_SCSIController','DeviceID','F','Name,Manufacturer,PNPDeviceID,DriverName,Status'),
        @('Win32_VideoController','DeviceID','G','Name,AdapterCompatibility,DriverVersion,PNPDeviceID,VideoProcessor,AdapterRAM,CurrentHorizontalResolution,CurrentVerticalResolution'),
        @('Win32_NetworkAdapter','DeviceID','E','Name,Manufacturer,MACAddress,PNPDeviceID,ServiceName,AdapterType,NetEnabled'),
        @('Win32_PnPEntity','DeviceID','C/K','Name,Manufacturer,Service,PNPDeviceID,ConfigManagerErrorCode'),
        @('Win32_PnPSignedDriver','DeviceID','D/K','DeviceName,DriverProviderName,DriverVersion,InfName,IsSigned'),
        @('Win32_SystemDriver','Name','D','DisplayName,PathName,State,StartMode,ServiceType'),
        @('Win32_Service','Name','D','DisplayName,PathName,State,StartMode'),
        @('Win32_OperatingSystem','CSName','compatibility','Caption,Version,BuildNumber,ServicePackMajorVersion,OSArchitecture,LastBootUpTime')
    )
    $wmiErrors=0
    if ($settings.IncludeWmi) {
        foreach ($q in $queries) {
            Write-Host ('WMI: ' + $q[0])
            $job=Start-Job -ArgumentList $q[0],$q[1],$q[3] -ScriptBlock {
                param($Class,$Key,$Properties)
                $ErrorActionPreference='Stop'
                foreach ($o in @(Get-WmiObject -Class $Class)) {
                    $v=@{ Identity=[string]$o.$Key }
                    foreach ($p in $Properties.Split(',')) { $v[$p]=[string](@($o.$p) -join '|') }
                    New-Object PSObject -Property $v
                }
            }
            try {
                $finished=Wait-Job -Job $job -Timeout $settings.WmiTimeoutSeconds
                if ($null -eq $finished) { throw 'WMI query timed out' }
                if ($job.State -ne 'Completed') {
                    $reason=($job.ChildJobs | ForEach-Object { [string]$_.JobStateInfo.Reason }) -join '; '
                    throw ('WMI job state: ' + $job.State + ' ' + $reason)
                }
                $items=@(Receive-Job -Job $job -ErrorAction Stop)
                foreach ($o in $items) {
                    foreach ($p in $q[3].Split(',')) {
                        $value=[string]$o.$p; $status='observed'
                        if ($value -match 'VMware|VEN_15AD|vmxnet|vmhgfs|vmmouse|vmtools|vgauth|VirtualBox|VBOX|QEMU|virtio|Xen') { $status='indicator' }
                        if ($p -eq 'ConfigManagerErrorCode' -and $value -ne '' -and $value -ne '0') { $status='inconsistent' }
                        [void]$rows.Add((New-Record @{Id=('wmi.'+$q[0]+'.'+$o.Identity+'.'+$p);Module='wmi';Category=($q[2]+'/J');Source=$q[0];Status=$status;Value=$value;Option='Read-only; see indicator matrix';Admin='no (provider restrictions possible)';Reboot='no';Effects='Inspection only'}))
                    }
                }
                [void]$rows.Add((New-Record @{Id=('wmi.coverage.'+$q[0]);Module='wmi';Category='J';Source=$q[0];Status='observed';Value=('Rows='+$items.Count);Option='Read-only';Admin='no';Reboot='no';Effects='Inspection only'}))
            } catch {
                $wmiErrors++
                [void]$rows.Add((New-Record @{Id=('wmi.coverage.'+$q[0]);Module='wmi';Category='J';Source=$q[0];Status='error';Value=$_.Exception.Message;Option='Repair provider/access and rescan';Admin='possibly';Reboot='no';Effects='Unknown coverage'}))
                Write-Log ('WMI failure '+$q[0]+' '+$_.Exception.Message)
            } finally { if ($job.State -eq 'Running') { Stop-Job $job }; Remove-Job $job -Force }
        }
    } else {
        [void]$rows.Add((New-Record @{Id='wmi.coverage';Module='wmi';Category='J';Source='settings.ini';Status='unsupported';Value='WMI disabled by user configuration';Option='Enable IncludeWmi';Admin='no';Reboot='no';Effects='Incomplete WMI coverage'}))
    }
    $rows | Export-Csv -Path (Join-Path $OutputDirectory 'observations.csv') -NoTypeInformation -Encoding UTF8
    $rows | Export-Clixml -Path (Join-Path $OutputDirectory 'observations.clixml') -Depth 6
    $rows | Select-Object Category,Module,Id,Status,Value,Source,Option,Admin,Reboot,Effects | ConvertTo-Html -Title 'VM fingerprint observations' | Out-File -FilePath (Join-Path $OutputDirectory 'report.html') -Encoding UTF8
    $rows | Where-Object {$_.Status -eq 'indicator' -or $_.Status -eq 'inconsistent' -or $_.Status -eq 'error'} | Select-Object Category,Status,Id,Value | Format-Table -AutoSize | Out-String -Width 220 | Out-File -FilePath (Join-Path $OutputDirectory 'summary.txt') -Encoding UTF8
    Write-AtomicText (Join-Path $OutputDirectory 'scan-state.txt') ('NativeExit='+$nativeExit+"`r`nWmiErrors="+$wmiErrors+"`r`nWmiEnabled="+$settings.IncludeWmi+"`r`nUTC="+(Get-Date).ToUniversalTime().ToString('o'))
    Write-AtomicText (Join-Path $script:ToolkitRoot 'reports\latest.txt') $OutputDirectory
    Write-Log ('Inventory complete: '+$OutputDirectory)
    Write-Host ('Report: '+$OutputDirectory)
    if ($nativeExit -eq 2 -or $wmiErrors -gt 0 -or !$settings.IncludeWmi) { Write-Warning 'Partial coverage. See errors/unsupported observations.'; exit 2 }
    exit 0
} catch { Write-Log ('Inventory failed: '+$_.Exception.Message); Write-Error $_; exit 1 }
