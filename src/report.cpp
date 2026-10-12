#include "vmtool.h"
#include <iomanip>
#include <cwchar>
namespace vm {
void Report::add(const std::string& m,const std::string& id,const std::string& c,
 const std::string& src,const std::string& v,const std::string& st,const std::string& opt,
 const std::string& adm,const std::string& reboot,const std::string& effects) {
    rows.push_back(Row{m,id,c,src,st,v,opt,adm,reboot,effects});
}
void Report::error(const std::string& m,const std::string& id,DWORD code,const std::string& detail) {
    add(m,id,m,"Windows API",detail+" error="+number(code),"error");
}
bool Report::incomplete() const {
    for (size_t i=0;i<rows.size();++i) if(rows[i].status=="error" || rows[i].status=="unsupported") return true;
    return false;
}
std::string utf8(const std::wstring& s) {
    if(s.empty()) return "";
    int n=WideCharToMultiByte(CP_UTF8,0,s.data(),(int)s.size(),NULL,0,NULL,NULL);
    std::string r(n,0); if(n) WideCharToMultiByte(CP_UTF8,0,s.data(),(int)s.size(),&r[0],n,NULL,NULL); return r;
}
std::wstring wide(const std::string& s) {
    if(s.empty()) return L"";
    int n=MultiByteToWideChar(CP_UTF8,0,s.data(),(int)s.size(),NULL,0);
    std::wstring r(n,0); if(n) MultiByteToWideChar(CP_UTF8,0,s.data(),(int)s.size(),&r[0],n); return r;
}
std::string number(uint64_t n) { std::ostringstream o; o<<n; return o.str(); }
std::string hex(uint64_t n) { std::ostringstream o; o<<"0x"<<std::hex<<std::uppercase<<n; return o.str(); }
std::string lower(std::string s) { for(size_t i=0;i<s.size();++i) if(s[i]>='A'&&s[i]<='Z') s[i]+=32; return s; }
bool marker(const std::string& v) {
    std::string s=lower(v);
    const char* patterns[]={"vmware","ven_15ad","vmxnet","vmhgfs","vmmouse","vmtools","vbox","virtualbox","qemu","xen","virtio","vgauth"};
    for(size_t i=0;i<sizeof(patterns)/sizeof(patterns[0]);++i) if(s.find(patterns[i])!=std::string::npos) return true;
    return false;
}
std::string utc() { SYSTEMTIME s; GetSystemTime(&s); char b[40]; wsprintfA(b,"%04u-%02u-%02uT%02u:%02u:%02uZ",s.wYear,s.wMonth,s.wDay,s.wHour,s.wMinute,s.wSecond); return b; }
std::string escape(const std::string& s) {
    std::string r;
    for(size_t i=0;i<s.size();++i) {
        unsigned char c=(unsigned char)s[i];
        if(c=='&') r+="&amp;"; else if(c=='<') r+="&lt;"; else if(c=='>') r+="&gt;";
        else if(c=='\"') r+="&quot;"; else if(c=='\'') r+="&apos;";
        else if(c=='\n') r+="&#10;"; else if(c=='\r') r+="&#13;"; else if(c=='\t') r+="&#9;";
        else if(c>=32) r+=c;
    } return r;
}
bool writeReport(const Report& r,const std::wstring& path) {
    std::ostringstream o; o<<"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<report schema=\"1\" tool=\"vmtool-1.0\" utc=\""<<utc()<<"\" complete=\""<<(r.incomplete()?"false":"true")<<"\">\n";
    for(size_t i=0;i<r.rows.size();++i) {
        const Row& a=r.rows[i];
        o<<" <observation module=\""<<escape(a.module)<<"\" id=\""<<escape(a.id)<<"\" category=\""<<escape(a.category)
         <<"\" source=\""<<escape(a.source)<<"\" status=\""<<escape(a.status)<<"\" admin=\""<<escape(a.admin)<<"\" reboot=\""<<escape(a.reboot)<<"\">"
         <<"<value>"<<escape(a.value)<<"</value><option>"<<escape(a.option)<<"</option><effects>"<<escape(a.effects)<<"</effects></observation>\n";
    } o<<"</report>\n";
    std::wstring tmp=path+L".tmp-"+wide(number(GetCurrentProcessId()));
    HANDLE h=CreateFileW(tmp.c_str(),GENERIC_WRITE,0,NULL,CREATE_NEW,FILE_ATTRIBUTE_NORMAL,NULL);
    if(h==INVALID_HANDLE_VALUE) return false;
    std::string data=o.str(); DWORD written=0;
    bool ok=WriteFile(h,data.data(),(DWORD)data.size(),&written,NULL)&&written==data.size()&&FlushFileBuffers(h);
    CloseHandle(h);
    if(ok) ok=MoveFileExW(tmp.c_str(),path.c_str(),MOVEFILE_WRITE_THROUGH)!=0;
    if(!ok) DeleteFileW(tmp.c_str());
    return ok;
}
}
