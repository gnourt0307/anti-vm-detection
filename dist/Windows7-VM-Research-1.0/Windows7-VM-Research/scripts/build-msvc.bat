@echo off
setlocal
cd /d "%~dp0.."
if not exist build mkdir build
where cl >nul 2>nul
if errorlevel 1 (
  echo Run from an x86 Native Tools command prompt with MSVC v142, not the latest toolset.
  exit /b 1
)
cl /nologo /EHsc /std:c++14 /O2 /W4 /MT /DWINVER=0x0601 /D_WIN32_WINNT=0x0601 /DUNICODE /D_UNICODE /Iinclude src\*.cpp /Fo:build\ /Fe:build\vmtool.exe /link /MACHINE:X86 /SUBSYSTEM:CONSOLE,6.01 setupapi.lib iphlpapi.lib ws2_32.lib advapi32.lib shell32.lib user32.lib
if errorlevel 1 exit /b 1
dumpbin /headers /imports build\vmtool.exe > build\msvc-imports.txt
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts\audit-pe.ps1 -Executable build\vmtool.exe -OutputPath build\pe-audit.txt
exit /b %ERRORLEVEL%
