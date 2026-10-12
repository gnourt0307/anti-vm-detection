# Third-party components and source provenance

Toolkit C++/PowerShell/batch source is independently written. No code from VMware-Hidden-Mode, anti-anti-vm-detection-dll, Pafish or al-khaser is compiled, linked, installed or included in the release. Links and source-review findings appear in docs/RESEARCH.md. Local research downloads are retained for review but excluded by package.ps1.

The supplied MinGW build statically includes GCC/libstdc++ runtime code. GCC 6.3.0 ships the GPL version 3 license with the GCC Runtime Library Exception version 3.1; copies from the installed compiler distribution accompany this binary under licenses/. The exception permits qualifying independent programs to use eligible runtime code under their own terms. Preserve relevant runtime notices when redistributing and review the exception for your build process.

The executable dynamically uses Microsoft Windows system DLLs. They are supplied by the target OS and are not redistributed here. The MSVC alternative has its own Microsoft toolchain/runtime license terms and is not the binary built for this delivery.

Research repository licenses observed: VMware-Hidden-Mode MIT; Pafish GPL-3.0; al-khaser GPL-2.0. No top-level license grant was found in the inspected anti-anti-vm-detection-dll tree; its MinHook dependency has separate licensing. Do not infer permission to copy unlicensed code.
