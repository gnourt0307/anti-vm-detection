param([string]$Executable='build\vmtool.exe',[string]$OutputPath='build\pe-audit.txt')
$ErrorActionPreference='Stop'
$bytes=[IO.File]::ReadAllBytes([IO.Path]::GetFullPath($Executable))
function U16([int]$Offset) { [BitConverter]::ToUInt16($bytes,$Offset) }
function U32([int]$Offset) { [BitConverter]::ToUInt32($bytes,$Offset) }
function CString([int]$Offset) {
    $end=$Offset
    while ($end -lt $bytes.Length -and $bytes[$end] -ne 0) { $end++ }
    if ($end -eq $bytes.Length) { throw 'Unterminated PE string.' }
    [Text.Encoding]::ASCII.GetString($bytes,$Offset,$end-$Offset)
}
if ((U16 0) -ne 0x5A4D) { throw 'Not an MZ executable.' }
$pe=U32 0x3C
if ((U32 $pe) -ne 0x4550 -or (U16 ($pe+4)) -ne 0x14C) { throw 'Not an x86 PE.' }
$opt=$pe+24
if ((U16 $opt) -ne 0x10B) { throw 'Not PE32.' }
$major=U16 ($opt+48);$minor=U16 ($opt+50)
if ($major -gt 6 -or ($major -eq 6 -and $minor -gt 1)) { throw 'Subsystem requires newer than Windows 7.' }
$sections=@();$sectionStart=$opt+(U16 ($pe+20))
for ($i=0;$i -lt (U16 ($pe+6));$i++) {
    $s=$sectionStart+$i*40
    $sections+=New-Object PSObject -Property @{Rva=(U32 ($s+12));Length=[Math]::Max((U32 ($s+8)),(U32 ($s+16)));Raw=(U32 ($s+20))}
}
function OffsetOf([uint32]$Rva) {
    foreach ($s in $sections) { if ($Rva -ge $s.Rva -and $Rva -lt ($s.Rva+$s.Length)) { return [int]($s.Raw+$Rva-$s.Rva) } }
    throw ('Unmapped PE RVA: '+$Rva)
}
$lines=New-Object Collections.ArrayList
[void]$lines.Add('Machine=0x014c (x86), PE32, Subsystem='+$major+'.'+$minor)
$dlls=@();$symbols=@();$descriptor=OffsetOf (U32 ($opt+104))
for ($i=0;$i -lt 128;$i++) {
    $d=$descriptor+$i*20;$nameRva=U32 ($d+12)
    if ($nameRva -eq 0) { break }
    $dll=CString (OffsetOf $nameRva);$dlls+=$dll.ToLowerInvariant()
    [void]$lines.Add('DLL '+$dll)
    $thunkRva=U32 $d;if (!$thunkRva) { $thunkRva=U32 ($d+16) }
    $thunk=OffsetOf $thunkRva
    for ($j=0;$j -lt 8192;$j++) {
        $v=U32 ($thunk+$j*4);if (!$v) { break }
        if (($v -band [uint32]2147483648) -ne 0) { throw 'Ordinal import needs a manual Windows 7 export review.' }
        $symbol=CString ((OffsetOf $v)+2);$symbols+=$symbol
        [void]$lines.Add('  '+$symbol)
    }
}
$allowed=@('advapi32.dll','iphlpapi.dll','kernel32.dll','msvcrt.dll','setupapi.dll','shell32.dll','user32.dll','ws2_32.dll')
foreach ($dll in $dlls) { if ($allowed -notcontains $dll) { throw ('Unreviewed dependency: '+$dll) } }
$modern=@('GetSystemTimePreciseAsFileTime','GetThreadInformation','SetThreadInformation','GetSystemCpuSetInformation','GetDpiForWindow','GetDpiForSystem','GetTempPath2W','WaitOnAddress','WakeByAddressSingle','WakeByAddressAll','SetThreadDescription')
foreach ($s in $symbols) { if ($modern -contains $s) { throw ('Post-Windows 7 import: '+$s) } }
[void]$lines.Add('Dynamic lookups: GetSystemFirmwareTable, EnumSystemFirmwareTables, GetLogicalProcessorInformation.')
[void]$lines.Add('This checks PE architecture/subsystem/dependencies and known newer imports; it is not a substitute for loading on Windows 7 SP1.')
$lines | Out-File -FilePath $OutputPath -Encoding ascii
Write-Host ('PE audit passed: '+$dlls.Count+' import descriptors, '+$symbols.Count+' imports. See '+$OutputPath)
