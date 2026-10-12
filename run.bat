@echo off
setlocal
cd /d "%~dp0"
if not exist "%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" (
  echo ERROR: Windows PowerShell 2.0 or later is required.
  exit /b 1
)
if not exist "build\vmtool.exe" (
  echo ERROR: Missing build\vmtool.exe. Build on Windows 11; see BUILD.md.
  exit /b 1
)
ver
echo Process architecture: %PROCESSOR_ARCHITECTURE%
if defined PROCESSOR_ARCHITEW6432 echo Native architecture: %PROCESSOR_ARCHITEW6432%
echo Configuration actions check Windows 7 SP1 x86 and elevation before proceeding.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\menu.ps1"
set "result=%ERRORLEVEL%"
if not "%result%"=="0" echo Toolkit exited with error %result%.
exit /b %result%
