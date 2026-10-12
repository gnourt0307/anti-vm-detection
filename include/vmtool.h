#ifndef VMTOOL_H
#define VMTOOL_H
#ifndef _WIN32_WINNT
#define _WIN32_WINNT 0x0601
#endif
#ifndef WINVER
#define WINVER 0x0601
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <winerror.h>
#include <string>
#include <vector>
#include <sstream>
#include <algorithm>
#include <stdint.h>
namespace vm {
struct Row {
    std::string module,id,category,source,status,value,option,admin,reboot,effects;
};
struct Report {
    std::vector<Row> rows;
    void add(const std::string& module,const std::string& id,const std::string& category,
             const std::string& source,const std::string& value,const std::string& status="observed",
             const std::string& option="Read-only; no supported guest identity override",
             const std::string& admin="no",const std::string& reboot="no",
             const std::string& effects="Inspection only");
    void error(const std::string& module,const std::string& id,DWORD code,const std::string& detail="");
    bool incomplete() const;
};
std::string utf8(const std::wstring& s);
std::wstring wide(const std::string& s);
std::string number(uint64_t n);
std::string hex(uint64_t n);
std::string lower(std::string s);
bool marker(const std::string& s);
std::string utc();
std::string escape(const std::string& s);
bool writeReport(const Report& r,const std::wstring& path);
void cpuid(uint32_t leaf,uint32_t sub,uint32_t out[4]);
void scanCpu(Report&); void scanHardware(Report&); void scanBios(Report&);
void scanRegistry(Report&); void scanNetwork(Report&); void scanStorage(Report&);
void scanGraphics(Report&); void scanServices(Report&); void scanTiming(Report&);
void scanCompatibility(Report&); void scanConsistency(Report&);
void parseSmbios(Report&,const std::vector<BYTE>&);
std::string regValue(HKEY root,const wchar_t* path,const wchar_t* name,DWORD& error);
}
#endif
