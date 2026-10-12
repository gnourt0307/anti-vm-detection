#include "vmtool.h"
#include <cstring>
namespace vm {
static std::string ascii(const BYTE* p,size_t n){std::string s;for(size_t i=0;i<n;++i)s+=p[i]>=32&&p[i]<127?(char)p[i]:'?';return s;}
static std::string smString(const std::vector<BYTE>& b,size_t begin,size_t end,unsigned index){
    if(!index)return "";
    unsigned current=1;size_t start=begin;
    for(size_t i=begin;i<=end;++i)if(i==end||b[i]==0){if(current==index)return ascii(&b[start],i-start);++current;start=i+1;}
    return "[invalid string index]";
}
void parseSmbios(Report& r,const std::vector<BYTE>& b) {
    if(b.size()<8){r.error("bios","smbios.header",ERROR_INVALID_DATA);return;}
    DWORD len=0;memcpy(&len,&b[4],4);if(len>b.size()-8){r.error("bios","smbios.length",ERROR_INVALID_DATA);return;}
    r.add("bios","smbios.version","B","firmware",number(b[1])+"."+number(b[2]));
    size_t end=8+len,pos=8;unsigned count=0;
    while(pos<end){
        if(end-pos<4||b[pos+1]<4||b[pos+1]>end-pos){r.error("bios","smbios.structure",ERROR_INVALID_DATA);return;}
        unsigned type=b[pos],size=b[pos+1];size_t strings=pos+size,stop=strings;
        while(stop+1<end && !(b[stop]==0&&b[stop+1]==0))++stop;
        if(stop+1>=end){r.error("bios","smbios.strings",ERROR_INVALID_DATA);return;}
        unsigned handle=b[pos+2]|(b[pos+3]<<8);std::string base="smbios."+number(type)+"."+hex(handle);
        if(type==0||type==1||type==2||type==3){
            const char* sys[]={"manufacturer","product","version","serial"};
            for(unsigned j=0;j<4;++j){unsigned off=4+j;if(type==0){const unsigned offsets[]={4,5,8,0};off=offsets[j];if(!off)continue;}if(type==3){const unsigned offsets[]={4,6,7,8};off=offsets[j];}
                if(off<size){std::string v=smString(b,strings,stop,b[pos+off]);std::string name=type==0?(j==0?"manufacturer":j==1?"version":"release-date"):sys[j];
                    if(type==3){const char* chassis[]={"manufacturer","version","serial","asset-tag"};name=chassis[j];}
                    r.add("bios",base+"."+name,"B","hypervisor firmware",v,v=="[invalid string index]"?"error":marker(v)?"indicator":"observed");}}
            if(type==0&&size>=18){uint64_t characteristics=0;memcpy(&characteristics,&b[pos+10],8);r.add("bios",base+".characteristics","B","firmware",hex(characteristics));}
            if(type==1&&size>=24){std::string uuid;for(size_t j=8;j<24;++j){const char*h="0123456789ABCDEF";uuid+=h[b[pos+j]>>4];uuid+=h[b[pos+j]&15];}r.add("bios",base+".uuid-raw","B","firmware",uuid);}
        }
        ++count;pos=stop+2;if(type==127)break;
    }r.add("bios","smbios.structure-count","B","firmware",number(count));
}
void scanBios(Report& r) {
    typedef UINT(WINAPI* GetTable)(DWORD,DWORD,PVOID,DWORD);typedef UINT(WINAPI* EnumTable)(DWORD,PVOID,DWORD);
    HMODULE k=GetModuleHandleW(L"kernel32.dll");GetTable get=(GetTable)GetProcAddress(k,"GetSystemFirmwareTable");EnumTable enumerate=(EnumTable)GetProcAddress(k,"EnumSystemFirmwareTables");
    if(!get||!enumerate){r.add("bios","firmware.api","B/H","Windows API","Firmware APIs unavailable","unsupported");return;}
    const DWORD rsmb=0x52534D42,acpi=0x41435049;
    UINT n=get(rsmb,0,NULL,0);
    if(n>=8&&n<=16*1024*1024){std::vector<BYTE>b(n);UINT got=get(rsmb,0,&b[0],n);if(got==n)parseSmbios(r,b);else r.error("bios","smbios.read",GetLastError(),"Table changed or read failed");}
    else r.error("bios","smbios.size",n?ERROR_INVALID_DATA:GetLastError());
    n=enumerate(acpi,NULL,0);
    if(!n||n>1024*1024||n%4){r.error("bios","acpi.enumerate",n?ERROR_INVALID_DATA:GetLastError());return;}
    std::vector<DWORD> ids(n/4);if(enumerate(acpi,&ids[0],n)!=n){r.error("bios","acpi.enumerate",GetLastError());return;}
    for(size_t i=0;i<ids.size();++i){std::string id="acpi."+hex(ids[i])+"."+number(i);UINT size=get(acpi,ids[i],NULL,0);
        if(size<36||size>16*1024*1024){r.error("bios",id,ERROR_INVALID_DATA,"Invalid/unavailable ACPI table size");continue;}
        std::vector<BYTE>b(size);if(get(acpi,ids[i],&b[0],size)!=size){r.error("bios",id,GetLastError());continue;}
        DWORD declared=0;memcpy(&declared,&b[4],4);if(declared<36||declared>size){r.error("bios",id,ERROR_INVALID_DATA,"Invalid ACPI length");continue;}
        unsigned sum=0;for(size_t j=0;j<declared;++j)sum+=b[j];
        std::string v="signature="+ascii(&b[0],4)+" OEM="+ascii(&b[10],6)+" table="+ascii(&b[16],8)+" creator="+ascii(&b[28],4)+" length="+number(declared)+" checksum="+((sum&255)?"invalid":"valid");
        r.add("bios",id,"H","hypervisor firmware",v,marker(v)?"indicator":"observed");
        if(sum&255)r.add("bios",id+".checksum","K","firmware","ACPI checksum mismatch","inconsistent");
    }
    r.add("bios","acpi.scope","H","Windows firmware API","Duplicate ACPI signatures return the first matching table; headers only; no physical-memory reads");
}
}
