#include "vmtool.h"
#include <cstdlib>
namespace vm {
void scanConsistency(Report& r){unsigned long logical=0,cores=0;std::string bit,vendor;bool pci=false,firmware=false;std::string sys,rawSys;
    for(size_t i=0;i<r.rows.size();++i){const Row&a=r.rows[i];if(a.id=="cpu.windows-logical")logical=strtoul(a.value.c_str(),NULL,10);if(a.id=="cpu.windows-cores")cores=strtoul(a.value.c_str(),NULL,10);if(a.id=="cpu.hypervisor-bit")bit=a.value;if(a.id=="cpu.hypervisor-vendor"&&a.status=="indicator")vendor=a.value;
        if(a.id=="reg.bios.SystemManufacturer")sys=a.value;
        if(a.id.find("smbios.1.")==0&&a.id.find(".manufacturer")!=std::string::npos)rawSys=a.value;
        if(a.module=="hardware"&&a.value.find("VEN_15AD")!=std::string::npos)pci=true;
        if(a.module=="bios"&&a.status=="indicator")firmware=true;}
    if(logical&&cores)r.add("consistency","consistency.cpu-counts","K","cross-check", "cores="+number(cores)+" logical="+number(logical),cores>logical?"inconsistent":"observed");
    else r.add("consistency","consistency.cpu-counts","K","cross-check","Insufficient observations","unknown");
    if(bit.empty())r.add("consistency","consistency.cpuid","K","cross-check","Insufficient observations","unknown");
    else r.add("consistency","consistency.cpuid","K","cross-check",bit=="0"&&!vendor.empty()?"Vendor leaf advertised while hypervisor bit is clear; possible filtered CPUID":"No contradiction observed in available CPUID evidence",bit=="0"&&!vendor.empty()?"inconsistent":"observed");
    if(!sys.empty()&&!rawSys.empty())r.add("consistency","consistency.smbios-registry","K","cross-check","registry="+sys+" SMBIOS="+rawSys,lower(sys)==lower(rawSys)?"observed":"inconsistent");
    else r.add("consistency","consistency.smbios-registry","K","cross-check","Insufficient observations","unknown");
    r.add("consistency","consistency.platform-evidence","K","cross-check","VMware PCI="+number(pci)+" firmware marker="+number(firmware)+"; mixed vendors can be legitimate; no fabricated identity suggested");
}
}
