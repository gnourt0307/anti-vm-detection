#include "vmtool.h"
#include <cstring>
namespace vm {
std::string regValue(HKEY root,const wchar_t* path,const wchar_t* name,DWORD& error) {
    HKEY k=NULL;error=RegOpenKeyExW(root,path,0,KEY_READ,&k);if(error)return "";
    DWORD type=0,n=0;error=RegQueryValueExW(k,name,NULL,&type,NULL,&n);
    if(error||n>1024*1024){RegCloseKey(k);if(!error)error=ERROR_INVALID_DATA;return "";}
    std::vector<BYTE> b(n+sizeof(wchar_t)*2,0);error=RegQueryValueExW(k,name,NULL,&type,&b[0],&n);RegCloseKey(k);if(error)return "";
    if(type==REG_DWORD&&n==4){DWORD v;memcpy(&v,&b[0],4);return number(v);}
    if(type==REG_SZ||type==REG_EXPAND_SZ||type==REG_MULTI_SZ){std::wstring v((wchar_t*)&b[0],n/sizeof(wchar_t));while(!v.empty()&&v.back()==0)v.pop_back();for(size_t i=0;i<v.size();++i)if(!v[i])v[i]=L'|';return utf8(v);}
    return "type="+number(type)+" bytes="+number(n);
}
void scanRegistry(Report& r) {
    const wchar_t* bios[]={L"BIOSVendor",L"BIOSVersion",L"BIOSReleaseDate",L"SystemManufacturer",L"SystemProductName",L"BaseBoardManufacturer",L"BaseBoardProduct"};
    for(size_t i=0;i<7;++i){DWORD e;std::string v=regValue(HKEY_LOCAL_MACHINE,L"HARDWARE\\DESCRIPTION\\System\\BIOS",bios[i],e);std::string id="reg.bios."+utf8(bios[i]);
        if(!e)r.add("registry",id,"C","firmware-derived registry",v,marker(v)?"indicator":"observed");else if(e==ERROR_FILE_NOT_FOUND)r.add("registry",id,"C","registry","Value absent","absent");else r.error("registry",id,e);}
    const wchar_t* keys[]={L"SOFTWARE\\VMware, Inc.\\VMware Tools",L"SYSTEM\\CurrentControlSet\\Services\\VMTools",L"SYSTEM\\CurrentControlSet\\Services\\vmhgfs",L"SYSTEM\\CurrentControlSet\\Services\\vmxnet3",L"SYSTEM\\CurrentControlSet\\Services\\VGAuthService"};
    for(size_t i=0;i<5;++i){HKEY k;LONG e=RegOpenKeyExW(HKEY_LOCAL_MACHINE,keys[i],0,KEY_READ,&k);std::string id="reg.key."+utf8(keys[i]);
        if(!e){RegCloseKey(k);r.add("registry",id,"C","installed integration software","Present","indicator","Use supported Tools installer for feature maintenance; no automatic uninstall");}
        else if(e==ERROR_FILE_NOT_FOUND)r.add("registry",id,"C","registry","Absent","absent");else r.error("registry",id,e);}
    DWORD e;std::string v=regValue(HKEY_LOCAL_MACHINE,L"SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run",L"VMware User Process",e);
    if(!e)r.add("registry","reg.tools-run","C","Windows startup configuration",v,"indicator","tools-user-autostart-off","yes (apply)","next logon","Clipboard, drag/drop and user-session integration may be unavailable");
    else if(e==ERROR_FILE_NOT_FOUND)r.add("registry","reg.tools-run","C","registry","Absent","absent");else r.error("registry","reg.tools-run",e);
    r.add("registry","reg.scope","C","collector","Process-native registry view; device enumeration via SetupAPI, service registry via SCM; no exhaustive hive dump");
}
}
