#include "vmtool.h"
#include <setupapi.h>
namespace vm {
static std::string property(HDEVINFO set,SP_DEVINFO_DATA& d,DWORD p,DWORD& err) {
    DWORD n=0,t=0;SetupDiGetDeviceRegistryPropertyW(set,&d,p,&t,NULL,0,&n);err=GetLastError();
    if(!n)return "";
    std::vector<BYTE>b(n+4,0);if(!SetupDiGetDeviceRegistryPropertyW(set,&d,p,&t,&b[0],n,&n)){err=GetLastError();return "";}err=0;
    std::wstring s((wchar_t*)&b[0],n/2);while(!s.empty()&&!s.back())s.pop_back();for(size_t i=0;i<s.size();++i)if(!s[i])s[i]=L'|';return utf8(s);
}
void scanHardware(Report& r) {
    HDEVINFO set=SetupDiGetClassDevsW(NULL,NULL,NULL,DIGCF_ALLCLASSES|DIGCF_PRESENT);
    if(set==INVALID_HANDLE_VALUE){r.error("hardware","pnp.enumeration",GetLastError());return;}
    DWORD i=0;SP_DEVINFO_DATA d={};d.cbSize=sizeof(d);
    for(;SetupDiEnumDeviceInfo(set,i,&d);++i){wchar_t id[4096]={0};if(!SetupDiGetDeviceInstanceIdW(set,&d,id,4096,NULL)){r.error("hardware","pnp.id."+number(i),GetLastError());continue;}
        const DWORD props[]={SPDRP_DEVICEDESC,SPDRP_MFG,SPDRP_HARDWAREID,SPDRP_SERVICE,SPDRP_CLASS,SPDRP_DRIVER};
        const char* names[]={"description","manufacturer","hardware-id","service","class","driver-key"};
        for(size_t j=0;j<6;++j){DWORD e=0;std::string v=property(set,d,props[j],e);std::string key="pnp."+utf8(id)+"."+names[j];
            if(!e)r.add("hardware",key,"C/K","PnP/hypervisor or driver",v,marker(v)||marker(utf8(id))?"indicator":"observed");
            else if(e==ERROR_INVALID_DATA||e==ERROR_FILE_NOT_FOUND)r.add("hardware",key,"C/K","PnP","Property absent","absent");else r.error("hardware",key,e);}
    }
    DWORD e=GetLastError();if(e!=ERROR_NO_MORE_ITEMS)r.error("hardware","pnp.enumeration",e);
    SetupDiDestroyDeviceInfoList(set);r.add("hardware","pnp.count","C/K","SetupAPI",number(i));
}
}
