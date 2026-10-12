#include "vmtool.h"
#include <cstring>
#ifdef _MSC_VER
#include <intrin.h>
#else
#include <cpuid.h>
#endif
namespace vm {
void cpuid(uint32_t leaf,uint32_t sub,uint32_t r[4]) {
#ifdef _MSC_VER
    int v[4]; __cpuidex(v,(int)leaf,(int)sub); memcpy(r,v,16);
#else
    __cpuid_count(leaf,sub,r[0],r[1],r[2],r[3]);
#endif
}
static std::string regs(uint32_t r[4]) { return "eax="+hex(r[0])+" ebx="+hex(r[1])+" ecx="+hex(r[2])+" edx="+hex(r[3]); }
void scanCpu(Report& r) {
    uint32_t c[4]; cpuid(0,0,c); uint32_t max=c[0]; char vendor[13]={0}; memcpy(vendor,c+1,4);memcpy(vendor+4,c+3,4);memcpy(vendor+8,c+2,4);
    r.add("cpu","cpu.vendor","A","CPUID",vendor);
    r.add("cpu","cpu.max-basic","A","CPUID",hex(max));
    if(max<1) {r.add("cpu","cpu.leaf1","A","CPUID","Leaf 1 unavailable","unsupported");return;}
    cpuid(1,0,c); bool hv=(c[2]&0x80000000u)!=0;
    uint32_t features1=c[2];
    unsigned family=(c[0]>>8)&15,model=(c[0]>>4)&15;
    if(family==6||family==15)model|=((c[0]>>16)&15)<<4;
    if(family==15)family+=(c[0]>>20)&255;
    r.add("cpu","cpu.signature","A","CPUID","family="+number(family)+" model="+number(model)+" stepping="+number(c[0]&15));
    r.add("cpu","cpu.leaf1","A","hypervisor/CPU",regs(c));
    r.add("cpu","cpu.hypervisor-bit","A","hypervisor/CPU",hv?"1":"0",hv?"indicator":"observed");
    r.add("cpu","cpu.logical-per-package","A","CPUID",number((c[1]>>16)&255));
    cpuid(0x40000000,0,c); uint32_t hvmax=c[0]; char hvvendor[13]={0};memcpy(hvvendor,c+1,12);
    if(hvmax>=0x40000000u && hvmax<=0x4000ffffu) {
        r.add("cpu","cpu.hypervisor-vendor","A","hypervisor",hvvendor,"indicator");
        for(uint32_t i=0x40000000;i<=hvmax && i<0x40000011;++i) {cpuid(i,0,c);r.add("cpu","cpu.hv."+hex(i),"A","hypervisor",regs(c));}
        if(hvmax>0x40000010) r.add("cpu","cpu.hv.limit","A","hypervisor","Only first 17 advertised leaves recorded; no vendor-specific interpretation");
    } else r.add("cpu","cpu.hypervisor-vendor","A","CPUID","No valid advertised hypervisor range; absence is not proof");
    cpuid(0x80000000,0,c); uint32_t ext=c[0];
    if(ext>=0x80000004) {char brand[49]={0};for(uint32_t i=0;i<3;++i){cpuid(0x80000002+i,0,c);memcpy(brand+16*i,c,16);}r.add("cpu","cpu.brand","A","CPUID",brand);}
    if(ext>=0x80000007) {cpuid(0x80000007,0,c);r.add("cpu","cpu.invariant-tsc","A","CPUID",(c[3]&(1u<<8))?"1":"0");}
    bool inconsistent=(features1&(1u<<28))&&!(features1&(1u<<26));
    if(max>=7) {cpuid(7,0,c);r.add("cpu","cpu.features7","A","CPUID",regs(c));if((c[1]&(1u<<5))&&!(features1&(1u<<28)))inconsistent=true;}
    r.add("cpu","cpu.feature-consistency","K","CPUID cross-check",inconsistent?"AVX without XSAVE or AVX2 without AVX":"No AVX/XSAVE feature contradiction; OSXSAVE availability is OS-dependent",inconsistent?"inconsistent":"observed");
    if(max>=0xB) for(uint32_t i=0;i<8;++i) {cpuid(0xB,i,c);if(!c[1]) break;r.add("cpu","cpu.topology."+number(i),"A","CPUID",regs(c));}
    SYSTEM_INFO si; GetSystemInfo(&si); r.add("cpu","cpu.windows-logical","A","Windows",number(si.dwNumberOfProcessors));
    // Private layout of the documented x86 structure for older MinGW headers.
    struct LogicalInfo { ULONG_PTR mask; DWORD relationship; ULONGLONG reserved[2]; };
    static_assert(sizeof(LogicalInfo)==24,"Unexpected x86 topology ABI");
    typedef BOOL(WINAPI* GetTopology)(LogicalInfo*,PDWORD);
    GetTopology topology=(GetTopology)GetProcAddress(GetModuleHandleW(L"kernel32.dll"),"GetLogicalProcessorInformation");
    if(!topology){r.add("cpu","cpu.windows-topology","A","Windows API","Topology API unavailable","unsupported");return;}
    DWORD n=0;topology(NULL,&n);
    if(!n||n>1024*1024||n%sizeof(LogicalInfo)) {r.error("cpu","cpu.windows-topology",n?ERROR_INVALID_DATA:GetLastError());return;}
    std::vector<BYTE> b(n); if(!topology((LogicalInfo*)&b[0],&n)){r.error("cpu","cpu.windows-topology",GetLastError());return;}
    unsigned cores=0,packages=0;LogicalInfo* p=(LogicalInfo*)&b[0];
    for(size_t i=0;i<n/sizeof(*p);++i){if(p[i].relationship==0)++cores;if(p[i].relationship==3)++packages;}
    r.add("cpu","cpu.windows-cores","A","Windows",number(cores));r.add("cpu","cpu.windows-packages","A","Windows",number(packages));
}
}
