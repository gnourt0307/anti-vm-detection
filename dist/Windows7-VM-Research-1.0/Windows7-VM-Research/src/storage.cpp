#include "vmtool.h"
#include <setupapi.h>
#include <winioctl.h>
#if defined(__MINGW32__) && !defined(__MINGW64_VERSION_MAJOR)
#include <ddk/ntddstor.h>
#endif
#include <cstring>
namespace vm {
static std::string descriptorString(const std::vector<BYTE>& b,DWORD off,size_t n){if(!off)return "";if(off>=n)return "[invalid offset]";size_t end=off;while(end<n&&b[end])++end;if(end==n)return "[unterminated]";std::string s;for(size_t i=off;i<end;++i)s+=b[i]>=32&&b[i]<127?(char)b[i]:'?';return s;}
void scanStorage(Report& r) {
    const GUID disk={0x53f56307,0xb6bf,0x11d0,{0x94,0xf2,0x00,0xa0,0xc9,0x1e,0xfb,0x8b}};
    HDEVINFO set=SetupDiGetClassDevsW(&disk,NULL,NULL,DIGCF_PRESENT|DIGCF_DEVICEINTERFACE);
    if(set==INVALID_HANDLE_VALUE){r.error("storage","disk.enumerate",GetLastError());return;}
    SP_DEVICE_INTERFACE_DATA d={};d.cbSize=sizeof(d);DWORD i=0;
    for(;SetupDiEnumDeviceInterfaces(set,NULL,&disk,i,&d);++i){DWORD n=0;SetupDiGetDeviceInterfaceDetailW(set,&d,NULL,0,&n,NULL);
        if(n<sizeof(SP_DEVICE_INTERFACE_DETAIL_DATA_W)||n>1024*1024){r.error("storage","disk.detail."+number(i),GetLastError());continue;}
        std::vector<BYTE>b(n);PSP_DEVICE_INTERFACE_DETAIL_DATA_W detail=(PSP_DEVICE_INTERFACE_DETAIL_DATA_W)&b[0];detail->cbSize=sizeof(*detail);
        if(!SetupDiGetDeviceInterfaceDetailW(set,&d,detail,n,NULL,NULL)){r.error("storage","disk.detail."+number(i),GetLastError());continue;}
        std::string id="disk."+utf8(detail->DevicePath);HANDLE h=CreateFileW(detail->DevicePath,0,FILE_SHARE_READ|FILE_SHARE_WRITE,NULL,OPEN_EXISTING,0,NULL);
        if(h==INVALID_HANDLE_VALUE){r.error("storage",id,GetLastError(),"Read-only descriptor access");continue;}
        STORAGE_PROPERTY_QUERY q={};q.PropertyId=StorageDeviceProperty;q.QueryType=PropertyStandardQuery;STORAGE_DESCRIPTOR_HEADER hdr={};DWORD got=0;
        if(!DeviceIoControl(h,IOCTL_STORAGE_QUERY_PROPERTY,&q,sizeof(q),&hdr,sizeof(hdr),&got,NULL)){r.error("storage",id,GetLastError());CloseHandle(h);continue;}
        if(hdr.Size<sizeof(STORAGE_DEVICE_DESCRIPTOR)||hdr.Size>1024*1024){r.error("storage",id,ERROR_INVALID_DATA);CloseHandle(h);continue;}
        std::vector<BYTE> data(hdr.Size,0);
        if(!DeviceIoControl(h,IOCTL_STORAGE_QUERY_PROPERTY,&q,sizeof(q),&data[0],(DWORD)data.size(),&got,NULL)){r.error("storage",id,GetLastError());CloseHandle(h);continue;}CloseHandle(h);
        if(got<sizeof(STORAGE_DEVICE_DESCRIPTOR)||got>data.size()){r.error("storage",id,ERROR_INVALID_DATA);continue;}
        STORAGE_DEVICE_DESCRIPTOR* s=(STORAGE_DEVICE_DESCRIPTOR*)&data[0];
        const DWORD offsets[]={s->VendorIdOffset,s->ProductIdOffset,s->ProductRevisionOffset,s->SerialNumberOffset};const char* names[]={"vendor","model","revision","serial"};
        for(size_t j=0;j<4;++j){std::string v=descriptorString(data,offsets[j],got);r.add("storage",id+"."+names[j],"F","storage device/hypervisor",v,v=="[invalid offset]"||v=="[unterminated]"?"error":marker(v)?"indicator":"observed","Host hardware settings only; never rewrite disk identity","no (scan)","power off for controller changes","Controller changes may cause INACCESSIBLE_BOOT_DEVICE; research manually");}
        r.add("storage",id+".bus-type","F","storage controller",number(s->BusType));
    }DWORD e=GetLastError();if(e!=ERROR_NO_MORE_ITEMS)r.error("storage","disk.enumerate",e);SetupDiDestroyDeviceInfoList(set);
    r.add("storage","disk.count","F","SetupAPI",number(i));
}
}
