#include "vmtool.h"
#include <tlhelp32.h>
namespace vm {
void scanServices(Report& r){
    SC_HANDLE scm=OpenSCManagerW(NULL,NULL,SC_MANAGER_ENUMERATE_SERVICE);
    if(!scm)r.error("services","services.open",GetLastError());
    else {DWORD resume=0,need=0,count=0;std::vector<BYTE>b(256*1024);BOOL ok=FALSE;
        do {ok=EnumServicesStatusExW(scm,SC_ENUM_PROCESS_INFO,SERVICE_WIN32|SERVICE_DRIVER,SERVICE_STATE_ALL,&b[0],(DWORD)b.size(),&need,&count,&resume,NULL);DWORD e=ok?0:GetLastError();
            if(!ok&&e!=ERROR_MORE_DATA){r.error("services","services.enumerate",e);break;}
            ENUM_SERVICE_STATUS_PROCESSW* p=(ENUM_SERVICE_STATUS_PROCESSW*)&b[0];
            for(DWORD i=0;i<count;++i){std::string id="service."+utf8(p[i].lpServiceName);std::string v=utf8(p[i].lpDisplayName)+" state="+number(p[i].ServiceStatusProcess.dwCurrentState)+" type="+number(p[i].ServiceStatusProcess.dwServiceType);
                SC_HANDLE s=OpenServiceW(scm,p[i].lpServiceName,SERVICE_QUERY_CONFIG);if(s){DWORD n=0;QueryServiceConfigW(s,NULL,0,&n);if(n&&n<1024*1024){std::vector<BYTE>data(n);QUERY_SERVICE_CONFIGW*c=(QUERY_SERVICE_CONFIGW*)&data[0];if(QueryServiceConfigW(s,c,n,&n)){v+=" start="+number(c->dwStartType)+" path="+utf8(c->lpBinaryPathName);r.add("services",id+".start","D","SCM configuration",number(c->dwStartType));}else r.error("services",id+".config",GetLastError());}else r.error("services",id+".config",GetLastError());CloseServiceHandle(s);}else r.error("services",id+".config",GetLastError());
                bool vg=lower(utf8(p[i].lpServiceName))=="vgauthservice";
                r.add("services",id,"D","installed service/driver",v,marker(v)||marker(id)?"indicator":"observed",vg?"vgauth-manual; service is not stopped":"Keep boot, storage, network and display drivers; use supported installer for maintenance",vg?"yes (apply)":"no (scan)",vg?"next boot":"no","Changing integration services affects guest authentication/automation; installed artifacts remain");}
            if(!ok&&count==0){r.error("services","services.progress",ERROR_MORE_DATA);break;}
        }while(!ok);CloseServiceHandle(scm);}
    HANDLE snap=CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS,0);if(snap==INVALID_HANDLE_VALUE){r.error("services","process.enumerate",GetLastError());return;}
    PROCESSENTRY32W p={};p.dwSize=sizeof(p);if(Process32FirstW(snap,&p)){do{std::string name=utf8(p.szExeFile);if(marker(name))r.add("services","process."+lower(name)+"."+number(p.th32ProcessID),"D","running software",name,"indicator");}while(Process32NextW(snap,&p));DWORD e=GetLastError();if(e!=ERROR_NO_MORE_FILES)r.error("services","process.enumerate",e);}else r.error("services","process.enumerate",GetLastError());CloseHandle(snap);
    r.add("services","process.scope","D","ToolHelp","Only names matching documented heuristic tokens are retained; no match does not prove absence");
}
}
