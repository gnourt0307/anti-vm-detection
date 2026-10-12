# Windows PowerShell 2.0 / .NET 2.0 compatible shared functions.
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$script:ToolkitRoot = Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent

function New-Record($Properties) { New-Object PSObject -Property $Properties }
function Get-Stamp { (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ') + '-' + [Guid]::NewGuid().ToString('N').Substring(0,8) }
function Write-Log([string]$Message) {
    $dir = Join-Path $script:ToolkitRoot 'logs'
    if (!(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Add-Content -LiteralPath (Join-Path $dir 'operations.log') -Encoding UTF8 -Value ((Get-Date).ToUniversalTime().ToString('o') + ' ' + $Message)
}
function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($identity)
    $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Assert-Guest {
    if (!(Test-Administrator)) { throw 'Apply/restore requires an elevated PowerShell window inside the guest.' }
    $os = Get-WmiObject Win32_OperatingSystem
    $cs = Get-WmiObject Win32_ComputerSystem
    if ($os.Version -notmatch '^6\.1\.' -or [int]$os.ServicePackMajorVersion -lt 1 -or [int]$os.ProductType -ne 1 -or [IntPtr]::Size -ne 4 -or $env:PROCESSOR_ARCHITEW6432) { throw 'Configuration is restricted to Windows 7 SP1 x86, not WOW64 or a development host.' }
    if ($cs.Manufacturer -notmatch 'VMware' -and $cs.Model -notmatch 'VMware') { throw 'A VMware guest identity was not confirmed. Read-only scanning remains available.' }
}
function Get-MachineIdentity {
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SOFTWARE\Microsoft\Cryptography')
    if ($null -eq $k) { throw 'Cannot read MachineGuid.' }
    try { $id = [string]$k.GetValue('MachineGuid') } finally { $k.Close() }
    $uuid = [string](Get-WmiObject Win32_ComputerSystemProduct).UUID
    if (!$id -or !$uuid) { throw 'Machine identity unavailable.' }
    $id + '/' + $uuid
}
function Assert-BackupStorage([string]$Directory=$script:ToolkitRoot) {
    $volume=[IO.Path]::GetPathRoot($Directory)
    if ($volume.StartsWith('\\')) { throw 'Configuration backups require a local NTFS directory, not a network/shared path.' }
    $drive=New-Object IO.DriveInfo($volume)
    if (!$drive.IsReady -or $drive.DriveFormat -ne 'NTFS' -or $drive.DriveType -ne [IO.DriveType]::Fixed) { throw 'Configuration requires a fixed local NTFS volume for ACLs and atomic journal replacement.' }
}
function Get-Sha256([string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $stream = [IO.File]::OpenRead($Path)
    try { ([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant() }
    finally { $stream.Close(); $sha.Clear() }
}
function Write-AtomicText([string]$Path,[string]$Text) {
    $Path=$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $temp = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    $bytes = (New-Object Text.UTF8Encoding($true)).GetBytes($Text)
    $f = New-Object IO.FileStream($temp,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None,4096,[IO.FileOptions]::WriteThrough)
    try { $f.Write($bytes,0,$bytes.Length); $f.Flush() } finally { $f.Close() }
    # PowerShell can marshal a null string as empty; use an actual backup path.
    # Retain the previous journal/pointer for interrupted-write investigation.
    if (Test-Path -LiteralPath $Path) { [IO.File]::Replace($temp,$Path,($Path+'.previous-'+[Guid]::NewGuid().ToString('N'))) } else { [IO.File]::Move($temp,$Path) }
}
function Read-SafeXml([string]$Path) {
    $settings = New-Object Xml.XmlReaderSettings
    $settings.ProhibitDtd = $true
    $settings.XmlResolver = $null
    $reader = [Xml.XmlReader]::Create($Path,$settings)
    try { $doc = New-Object Xml.XmlDocument; $doc.XmlResolver = $null; $doc.Load($reader); return ,$doc } finally { $reader.Close() }
}
function Get-NativeRows([string]$Path) {
    $doc = Read-SafeXml $Path
    if ($doc.report.schema -ne '1') { throw 'Unsupported native report schema.' }
    foreach ($o in $doc.report.observation) {
        New-Record @{ Id=[string]$o.id; Module=[string]$o.module; Category=[string]$o.category; Source=[string]$o.source; Status=[string]$o.status; Value=[string]$o.value; Option=[string]$o.option; Admin=[string]$o.admin; Reboot=[string]$o.reboot; Effects=[string]$o.effects }
    }
}
function Invoke-NativeScan([string]$Path,[string]$Module='all') {
    $exe = Join-Path $script:ToolkitRoot 'build\vmtool.exe'
    if (!(Test-Path -LiteralPath $exe)) { throw 'build\vmtool.exe is missing. Build on Windows 11; see BUILD.md.' }
    if ($Path.Contains('"')) { throw 'Invalid report path.' }
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $exe
    $start.Arguments = '--out "' + $Path + '" --module ' + $Module
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $p = [Diagnostics.Process]::Start($start)
    try {
        if (!$p.WaitForExit(120000)) { $p.Kill(); throw 'Native scan exceeded 120 seconds; no completed report accepted.' }
        $code = $p.ExitCode
    } finally { $p.Dispose() }
    if ($code -ne 0 -and $code -ne 2) { throw ('Native scanner failed: exit ' + $code) }
    Write-Log ('Native scan exit=' + $code + ' output=' + $Path)
    return $code
}
function Get-Settings {
    $result = @{ WmiTimeoutSeconds=45; IncludeWmi=$true }
    foreach ($line in (Get-Content -LiteralPath (Join-Path $script:ToolkitRoot 'config\settings.ini'))) {
        $s = $line.Trim()
        if (!$s -or $s.StartsWith('#') -or $s.StartsWith(';') -or $s.StartsWith('[')) { continue }
        if ($s -notmatch '^([^=]+)=(.*)$') { throw ('Invalid settings line: ' + $s) }
        $key = $matches[1].Trim(); $value = $matches[2].Trim()
        switch ($key) {
            'WmiTimeoutSeconds' { $n=[int]$value; if ($n -lt 5 -or $n -gt 120) { throw 'WMI timeout must be 5..120 seconds.' }; $result[$key]=$n }
            'IncludeWmi' { if ($value -notmatch '^(true|false)$') { throw 'IncludeWmi must be true/false.' }; $result[$key]=($value -eq 'true') }
            default { throw ('Unknown setting: ' + $key) }
        }
    }
    $result
}
function Get-Options {
    New-Record @{Id='tools-user-autostart-off'; Description='Remove only HKLM Run: VMware User Process'; Admin='yes'; Reboot='next logon'; Effects='User-session clipboard, drag/drop, tray and related integration can stop at next logon. Running process and Tools service are preserved.'}
    New-Record @{Id='vgauth-manual'; Description='Set VGAuthService to Manual without stopping it'; Admin='yes'; Reboot='next boot/start'; Effects='Guest authentication and automated guest operations may fail until started. Manual services can still start on demand; no promise of fewer visible processes.'}
}
function Get-OptionDefinition([string]$Id) {
    switch ($Id) {
        'tools-user-autostart-off' { New-Record @{Id=$Id;Kind='Registry';Path='SOFTWARE\Microsoft\Windows\CurrentVersion\Run';Name='VMware User Process'} }
        'vgauth-manual' { New-Record @{Id=$Id;Kind='Service';Path='SYSTEM\CurrentControlSet\Services\VGAuthService';Name='VGAuthService'} }
        default { throw 'Unknown configuration option; no arbitrary paths or services are accepted.' }
    }
}
function Get-OptionState([string]$Id) {
    $d = Get-OptionDefinition $Id
    $k = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($d.Path)
    if ($null -eq $k) { return (New-Record @{Exists=$false;Type='Absent';Value=''}) }
    try {
        if ($d.Kind -eq 'Registry') {
            if (@($k.GetValueNames()) -notcontains $d.Name) { return (New-Record @{Exists=$false;Type='Absent';Value=''}) }
            $type = $k.GetValueKind($d.Name).ToString()
            if ($type -ne 'String' -and $type -ne 'ExpandString') { throw 'Unexpected Run registry type; refusing changes.' }
            New-Record @{Exists=$true;Type=$type;Value=[string]$k.GetValue($d.Name,'',[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}
        } else {
            $s = Get-WmiObject Win32_Service -Filter "Name='VGAuthService'"
            if ($null -eq $s) { throw 'VGAuthService registry and SCM disagree.' }
            $start = [int]$k.GetValue('Start',-1)
            if (@(2,3,4) -notcontains $start) { throw 'Unexpected service start mode.' }
            $delayed = [int]$k.GetValue('DelayedAutoStart',0)
            if ($delayed -ne 0) { throw 'Delayed auto-start is not supported by this experiment; no changes applied.' }
            $mode = @{2='Auto';3='Manual';4='Disabled'}[$start]
            if ($s.StartMode -ne $mode) { throw 'Service start mode disagrees with registry.' }
            New-Record @{Exists=$true;Type='ServiceStart';Value=[string]$start}
        }
    } finally { $k.Close() }
}
function Get-DesiredState([string]$Id) {
    $d=Get-OptionDefinition $Id
    if ($d.Kind -eq 'Registry') { New-Record @{Exists=$false;Type='Absent';Value=''} }
    else { New-Record @{Exists=$true;Type='ServiceStart';Value='3'} }
}
function Test-StateEqual($A,$B) { ($A.Exists -eq $B.Exists -and $A.Type -ceq $B.Type -and [string]$A.Value -ceq [string]$B.Value) }
function Set-OptionState([string]$Id,$State) {
    $d = Get-OptionDefinition $Id
    if ($d.Kind -eq 'Registry') {
        $k=[Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($d.Path,$true)
        if ($null -eq $k) { throw 'Expected Run key missing; refusing to recreate a changed system structure.' }
        try {
            if ($State.Exists) {
                if ($State.Type -ne 'String' -and $State.Type -ne 'ExpandString') { throw 'Invalid registry type.' }
                $type = [Enum]::Parse([Microsoft.Win32.RegistryValueKind],$State.Type)
                $k.SetValue($d.Name,[string]$State.Value,$type)
            } else { $k.DeleteValue($d.Name,$false) }
            $k.Flush()
        } finally { $k.Close() }
    } else {
        $modes=@{'2'='Automatic';'3'='Manual';'4'='Disabled'}
        if (!$State.Exists -or $State.Type -ne 'ServiceStart' -or !$modes.ContainsKey([string]$State.Value)) { throw 'Invalid service state.' }
        $s=Get-WmiObject Win32_Service -Filter "Name='VGAuthService'"
        if ($null -eq $s) { throw 'VGAuthService missing.' }
        $rc=$s.ChangeStartMode($modes[[string]$State.Value])
        if ($rc.ReturnValue -ne 0) { throw ('ChangeStartMode failed: ' + $rc.ReturnValue) }
    }
}
function Enter-TransactionLock {
    $dir=Join-Path $script:ToolkitRoot 'backups'
    if (!(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    try { return (New-Object IO.FileStream((Join-Path $dir 'transaction.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)) }
    catch { throw 'Another apply/restore operation holds the transaction lock. If interrupted, close the old process before retrying.' }
}
function Assert-NoPendingTransaction {
    foreach ($d in @(Get-ChildItem -LiteralPath (Join-Path $script:ToolkitRoot 'backups') | Where-Object {$_.PSIsContainer})) {
        $manifest=Join-Path $d.FullName 'manifest.clixml'
        if (Test-Path -LiteralPath $manifest) {
            $state=Join-Path $d.FullName 'journal.txt'
            if (!(Test-Path -LiteralPath $state) -or (Get-Content -LiteralPath $state | Select-Object -First 1) -ne 'Restored') { throw ('Resolve existing transaction first: ' + $d.FullName) }
        }
    }
}
