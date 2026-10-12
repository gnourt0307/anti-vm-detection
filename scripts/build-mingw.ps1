param([string]$Compiler='g++')
$ErrorActionPreference='Stop'
$root=Split-Path (Split-Path $MyInvocation.MyCommand.Path -Parent) -Parent
Push-Location $root
try {
    if (!(Test-Path build)) { New-Item -ItemType Directory build | Out-Null }
    $sources=@(Get-ChildItem src -Filter *.cpp | ForEach-Object {$_.FullName})
    $flags=@('-std=c++11','-O2','-Wall','-Wextra','-Wpedantic','-Werror','-D_WIN32_WINNT=0x0601','-DWINVER=0x0601','-DUNICODE','-D_UNICODE','-Iinclude')
    & $Compiler @flags @sources '-o' 'build/vmtool.exe' '-static' '-static-libgcc' '-static-libstdc++' '-Wl,--major-subsystem-version,6,--minor-subsystem-version,1' '-lsetupapi' '-liphlpapi' '-lws2_32' '-ladvapi32' '-lshell32'
    if ($LASTEXITCODE -ne 0) { throw 'Compilation failed.' }
    & $Compiler --version | Out-File -FilePath build/compiler.txt -Encoding ascii
    & (Join-Path $root 'scripts\audit-pe.ps1') -Executable (Join-Path $root 'build\vmtool.exe') -OutputPath (Join-Path $root 'build\pe-audit.txt')
} finally { Pop-Location }
