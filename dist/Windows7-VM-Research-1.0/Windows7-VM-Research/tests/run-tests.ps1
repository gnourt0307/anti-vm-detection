param([string]$Compiler='g++')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
Push-Location $root
try {
    & (Join-Path $root 'scripts\build-mingw.ps1') -Compiler $Compiler
    & $Compiler '-std=c++11' '-O2' '-Wall' '-Wextra' '-Werror' '-D_WIN32_WINNT=0x0601' '-DWINVER=0x0601' '-DUNICODE' '-D_UNICODE' '-Iinclude' 'tests/native_tests.cpp' 'src/report.cpp' 'src/bios.cpp' '-o' 'build/native-tests.exe' '-static' '-static-libgcc' '-static-libstdc++'
    if ($LASTEXITCODE -ne 0) { throw 'Native test build failed.' }
    & .\build\native-tests.exe
    if ($LASTEXITCODE -ne 0) { throw 'Native tests failed.' }
    & (Join-Path $root 'tests\workflow_tests.ps1')
    $scratch=Join-Path $root ('reports\smoke-'+[Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $scratch | Out-Null
    $exe=Join-Path $root 'build\vmtool.exe'
    foreach ($module in @('compatibility','cpu','bios','registry','hardware','network','storage','graphics','services','timing','consistency','all')) {
        $report=Join-Path $scratch ($module+'.xml')
        & $exe --out $report --module $module
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 2) { throw ('Module failed: '+$module) }
        [xml]$xml=[IO.File]::ReadAllText($report)
        if ($xml.report.schema -ne '1' -or @($xml.report.observation).Count -eq 0) { throw ('Invalid report: '+$module) }
        $ids=@{}
        foreach ($o in $xml.report.observation) { if ($ids.ContainsKey($o.id)) { throw ('Duplicate native ID: '+$o.id) }; $ids[$o.id]=$true }
    }
    & $exe --out (Join-Path $scratch 'cpu.xml') --module cpu
    if ($LASTEXITCODE -ne 1) { throw 'Existing report was not protected.' }
    & $exe --out (Join-Path $scratch 'invalid.xml') --module invalid
    if ($LASTEXITCODE -ne 1) { throw 'Unknown module was not rejected.' }
    $unicodeName='scan space '+[char]0x00E9+'.xml'
    & $exe --out (Join-Path $scratch $unicodeName) --module compatibility
    if ($LASTEXITCODE -ne 0) { throw 'Unicode path scan failed.' }
    [xml]$xml=[IO.File]::ReadAllText((Join-Path $scratch $unicodeName))
    & $exe --out (Join-Path $scratch 'missing\report.xml') --module compatibility
    if ($LASTEXITCODE -ne 1) { throw 'Missing output directory did not fail.' }
    $fixture=Join-Path $scratch 'test.vmx'
    @('guestOS = "windows7"','numvcpus = "2"','numvcpus = "4"','ethernet0.addressType = "generated"','unparseable test line') | Out-File -FilePath $fixture -Encoding ascii
    $hashBefore=(Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash
    # Host-only runner uses PS5 Get-FileHash; guest workflow does not.
    $auditOut=Join-Path $scratch 'vmx-audit'
    & "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'host\vmware_config_audit.ps1') -VmxPath $fixture -OutputDirectory $auditOut
    if ($LASTEXITCODE -ne 0) { throw 'VMX fixture audit failed.' }
    if ((Get-FileHash -LiteralPath $fixture -Algorithm SHA256).Hash -ne $hashBefore) { throw 'Audit modified VMX.' }
    $audit=@(Import-Csv (Join-Path $auditOut 'vmx-audit.csv'))
    if (@($audit | Where-Object {$_.Status -like 'duplicate*'}).Count -ne 1 -or @($audit | Where-Object {$_.Status -eq 'unknown-syntax'}).Count -ne 1) { throw 'VMX diagnostics missing.' }
    $errorsFound=0
    foreach ($file in @(Get-ChildItem scripts,host,tests -Filter *.ps1)) {
        $tokens=$null;$errors=$null
        [Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
        if ($errors.Count) { $errorsFound+=$errors.Count; $errors | Out-String | Write-Host }
    }
    if ($errorsFound) { throw 'PowerShell parse errors.' }
    Write-Host ('All local tests passed. Host smoke artifacts: '+$scratch)
    Write-Host 'PowerShell 2.0, Windows 7 and real guest apply/restore still require target acceptance.'
    $global:LASTEXITCODE=0
} finally { Pop-Location }
