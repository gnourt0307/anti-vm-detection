param([string]$Before='',[string]$After='',[string]$OutputDirectory='')
. (Join-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) 'common.ps1')
function Read-Observations([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Container) { $Path=Join-Path $Path 'observations.csv' }
    if ([IO.Path]::GetExtension($Path) -eq '.xml') { return @(Get-NativeRows $Path) }
    return @(Import-Csv -Path $Path)
}
function Compare-Observations($Old,$New) {
    $a=@{};$b=@{}
    foreach ($r in $Old) { if ($a.ContainsKey($r.Id)) { throw ('Duplicate before ID: '+$r.Id) }; $a[$r.Id]=$r }
    foreach ($r in $New) { if ($b.ContainsKey($r.Id)) { throw ('Duplicate after ID: '+$r.Id) }; $b[$r.Id]=$r }
    foreach ($id in @(@($a.Keys)+@($b.Keys) | Sort-Object -Unique)) {
        $x=$a[$id];$y=$b[$id];$change='Unchanged';$bs='missing';$as='missing';$bv='';$av='';$category='';$module=''
        if ($null -ne $x) { $bs=$x.Status;$bv=$x.Value;$category=$x.Category;$module=$x.Module }
        if ($null -ne $y) { $as=$y.Status;$av=$y.Value;$category=$y.Category;$module=$y.Module }
        if (@('error','unsupported','unknown','missing') -contains $bs -or @('error','unsupported','unknown','missing') -contains $as) { $change='Unknown/coverage-or-enumeration-change' }
        elseif ($bs -cne $as -or $bv -cne $av) { $change='Changed' }
        New-Record @{Id=$id;Category=$category;Module=$module;BeforeStatus=$bs;AfterStatus=$as;BeforeValue=$bv;AfterValue=$av;Change=$change}
    }
}
# Tests dot-source this file for the pure comparison functions.
if ($MyInvocation.InvocationName -eq '.') { return }
try {
    if (!$Before) { $Before=Read-Host 'Before scan directory or native XML' }
    if (!$After) { $After=Read-Host 'After scan directory or native XML' }
    if (!$Before -or !$After) { throw 'Both reports are required.' }
    if (!$OutputDirectory) { $OutputDirectory=Join-Path $script:ToolkitRoot ('reports\compare-'+(Get-Stamp)) }
    if (Test-Path -LiteralPath $OutputDirectory) { throw 'Use a new output directory.' }
    $old=@(Read-Observations $Before);$new=@(Read-Observations $After)
    $diff=@(Compare-Observations $old $new)
    New-Item -ItemType Directory -Path $OutputDirectory | Out-Null
    $diff | Export-Csv -Path (Join-Path $OutputDirectory 'comparison.csv') -NoTypeInformation -Encoding UTF8
    $diff | ConvertTo-Html -Title 'Measured fingerprint comparison' | Out-File -FilePath (Join-Path $OutputDirectory 'comparison.html') -Encoding UTF8
    $summary=foreach ($cat in @($diff | Select-Object -ExpandProperty Category -Unique | Sort-Object)) {
        $d=@($diff | Where-Object {$_.Category -eq $cat})
        New-Record @{Category=$cat;BeforeIndicators=@($d | Where-Object {$_.BeforeStatus -eq 'indicator'}).Count;AfterIndicators=@($d | Where-Object {$_.AfterStatus -eq 'indicator'}).Count;Changed=@($d | Where-Object {$_.Change -eq 'Changed'}).Count;Unknown=@($d | Where-Object {$_.Change -like 'Unknown*'}).Count}
    }
    $summary | Export-Csv -Path (Join-Path $OutputDirectory 'summary.csv') -NoTypeInformation -Encoding UTF8
    $summary | Format-Table -AutoSize
    Write-Host 'Counts describe measured rows, not confidence or undetectability. Missing/error rows are unknown; process IDs and timing naturally vary.'
    Write-Log ('Compared '+$Before+' with '+$After+' output='+$OutputDirectory)
    Write-Host ('Comparison: '+$OutputDirectory)
    exit 0
} catch { Write-Log ('Comparison failed: '+$_.Exception.Message); Write-Host ('ERROR: '+$_.Exception.Message); exit 1 }
