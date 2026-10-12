# Building on Windows 11 for Windows 7 SP1 x86

## Build actually performed

The development environment has `C:\MinGW\bin\g++.exe`, MinGW.org GCC 6.3.0-1, target `mingw32`. The shipped build uses its Win32 headers/import libraries and statically links GCC/libstdc++ support. It still imports the Windows-supplied MSVCRT and system DLLs. No MinGW DLL or Visual C++ redistributable was found among this build's imports.

```powershell
# Windows PowerShell, at repository root
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\build-mingw.ps1 -Compiler C:\MinGW\bin\g++.exe

# Equivalent compiler command; quote the comma-containing linker option in PowerShell
g++ -std=c++11 -O2 -Wall -Wextra -Wpedantic -Werror -D_WIN32_WINNT=0x0601 -DWINVER=0x0601 -DUNICODE -D_UNICODE -Iinclude src/*.cpp -o build/vmtool.exe -static -static-libgcc -static-libstdc++ '-Wl,--major-subsystem-version,6,--minor-subsystem-version,1' -lsetupapi -liphlpapi -lws2_32 -ladvapi32 -lshell32
```

The source statically asserts a 32-bit process. A native x64 MinGW compiler without working `-m32` libraries cannot build it; use a complete i686 toolchain. A newer compiler is a different build and requires a new import audit and guest load test. GCC 6.3.0 is old: this build is a reproducible laboratory artifact, not a claim that the compiler remains maintained.

## MSVC alternative (not compiled in this environment)

Install Visual Studio 2022 Build Tools on Windows 11 with the **v142 / VS2019 C++ x86/x64 build tools** and Windows 10 SDK **10.0.19041.0**. Select v142 explicitly; do not silently substitute the latest toolset. The code uses C++11 facilities; `/std:c++14` is suitable for this MSVC toolset. Select the x86 compiler environment:

```bat
call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsall.bat" x86 10.0.19041.0 -vcvars_ver=14.29
cl /Bv
scripts\build-msvc.bat
```

Adjust the installation path for Community/Professional installations. The batch build runs:

```bat
cl /nologo /EHsc /std:c++14 /O2 /W4 /MT /DWINVER=0x0601 /D_WIN32_WINNT=0x0601 /DUNICODE /D_UNICODE /Iinclude src\*.cpp /Fo:build\ /Fe:build\vmtool.exe /link /MACHINE:X86 /SUBSYSTEM:CONSOLE,6.01 setupapi.lib iphlpapi.lib ws2_32.lib advapi32.lib shell32.lib user32.lib
dumpbin /headers /imports build\vmtool.exe
```

`/MT` links the selected release runtime statically, but Windows dependencies remain. Avoid `/MD` unless you deliberately deploy a matching Windows 7-compatible runtime and validate its patch requirements. Microsoft's [platform support table](https://learn.microsoft.com/en-us/cpp/overview/supported-platforms-visual-cpp) states that Visual Studio 2026 no longer targets Windows 7. [Target version macros](https://learn.microsoft.com/en-us/cpp/porting/modifying-winver-and-win32-winnt) limit declarations; they cannot guarantee the selected compiler runtime's minimum OS.

The exact MSVC command is provided for reproduction; the selected installation, SDK, compiler/runtime combination and resulting executable have **not** been tested here. Check `cl /Bv`, run the PE audit, review all imports, and run the guest acceptance tests before using that build.

## Dependency inspection

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\audit-pe.ps1 -Executable .\build\vmtool.exe -OutputPath .\build\pe-audit.txt
C:\MinGW\bin\objdump.exe -p .\build\vmtool.exe
```

The included audit parses PE32 directly, checks x86 and subsystem <=6.1, enumerates imported symbols, rejects unknown DLLs/ordinal imports and a set of known newer APIs. It is a conservative guard, **not a complete Windows API compatibility database**. Review `build/pe-audit.txt` after any compiler or source change. The reviewed build uses ADVAPI32, IPHLPAPI, KERNEL32, MSVCRT, SETUPAPI, SHELL32, USER32. Firmware and processor-topology entry points are obtained dynamically and checked for absence. Standard Win7 APIs are linked normally; an OS older than the target is not supported. No firmware driver is installed.

MinGW.org's old headers place storage descriptors in `ddk/ntddstor.h`; this is only a compile-time structure declaration, not a kernel dependency. The documented x86 `SYSTEM_LOGICAL_PROCESSOR_INFORMATION` layout is declared privately because these headers omit it. Its 24-byte layout is asserted. Network, storage and firmware reads are bounded, and malformed firmware structures produce collection errors.

## Local tests and distribution

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\run-tests.ps1
# Host only: PowerShell 5.1 / .NET 4.5+ packaging
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

The package includes executable/source/scripts/docs/tests/runtime notices and empty report/log/backup directories. It excludes local reports, logs, backups, downloaded research source and test executables. Transfer the entire extracted folder, not just `vmtool.exe`, to run the menu. The executable alone supports native diagnostics without PowerShell.

On the guest, loading `vmtool.exe --help` is the first dependency test. An entry-point/DLL error means the build failed the compatibility gate regardless of host results. The complete validation matrix is in [docs/VALIDATION.md](docs/VALIDATION.md).
