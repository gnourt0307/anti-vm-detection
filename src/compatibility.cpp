#include "vmtool.h"
namespace vm {
void scanCompatibility(Report& r) {
    OSVERSIONINFOEXW os={};os.dwOSVersionInfoSize=sizeof(os);
    if(!GetVersionExW((OSVERSIONINFOW*)&os)){r.error("compatibility","compat.os",GetLastError());return;}
    SYSTEM_INFO si;GetNativeSystemInfo(&si);
    bool target=os.dwMajorVersion==6&&os.dwMinorVersion==1&&os.wServicePackMajor>=1&&os.wProductType==VER_NT_WORKSTATION&&si.wProcessorArchitecture==PROCESSOR_ARCHITECTURE_INTEL;
    r.add("compatibility","compat.version","compatibility","Windows version API",number(os.dwMajorVersion)+"."+number(os.dwMinorVersion)+" build="+number(os.dwBuildNumber)+" SP="+number(os.wServicePackMajor)+"; modern hosts may report a compatibility version");
    r.add("compatibility","compat.target","compatibility","Windows",target?"Win7 SP1 x86 target":"Non-target host; read-only diagnostics allowed");
    r.add("compatibility","compat.process-bits","compatibility","compiler",number(sizeof(void*)*8));
    r.add("compatibility","compat.native-architecture","compatibility","Windows",number(si.wProcessorArchitecture));
    SID_IDENTIFIER_AUTHORITY auth=SECURITY_NT_AUTHORITY; PSID sid=NULL;BOOL admin=FALSE;
    if(AllocateAndInitializeSid(&auth,2,SECURITY_BUILTIN_DOMAIN_RID,DOMAIN_ALIAS_RID_ADMINS,0,0,0,0,0,0,&sid)){if(!CheckTokenMembership(NULL,sid,&admin)) r.error("compatibility","compat.token",GetLastError());FreeSid(sid);}
    else r.error("compatibility","compat.token",GetLastError());
    r.add("compatibility","compat.elevated","compatibility","token",admin?"yes":"no");
    MEMORYSTATUSEX mem={};mem.dwLength=sizeof(mem);if(GlobalMemoryStatusEx(&mem)) r.add("compatibility","compat.memory-bytes","compatibility","Windows",number(mem.ullTotalPhys));else r.error("compatibility","compat.memory",GetLastError());
}
}
