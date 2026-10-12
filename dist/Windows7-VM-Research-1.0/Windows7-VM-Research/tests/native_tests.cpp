#include "vmtool.h"
#include <iostream>
#include <cstring>
#include <stdexcept>
static unsigned checks=0;
static void require(bool condition,const char* message){if(!condition)throw std::runtime_error(message);++checks;}
int main(){try{
    require(vm::escape("<&>\"'\n\t\r\001")=="&lt;&amp;&gt;&quot;&apos;&#10;&#9;&#13;","XML escaping and control removal");
    require(vm::utf8(vm::wide("caf\xc3\xa9"))=="caf\xc3\xa9","UTF-8 round trip");
    require(vm::marker("PCI\\VEN_15AD&DEV_0405"),"case insensitive hardware marker");
    require(!vm::marker("Realtek Ethernet"),"unrelated hardware not flagged");
    vm::Report shortReport;vm::parseSmbios(shortReport,std::vector<BYTE>(7,0));require(shortReport.incomplete(),"short SMBIOS rejected");
    // RawSMBIOSData prefix followed by a type-1 record and a double-NUL string area.
    const BYTE body[]={1,8,1,0,1,2,0,0,'V','M','w','a','r','e',0,'T','e','s','t',0,0,127,4,2,0,0,0};
    std::vector<BYTE> good(8+sizeof(body),0);good[1]=2;good[2]=7;DWORD n=sizeof(body);memcpy(&good[4],&n,4);memcpy(&good[8],body,sizeof(body));
    vm::Report parsed;vm::parseSmbios(parsed,good);require(!parsed.incomplete(),"valid SMBIOS accepted");
    bool found=false;for(size_t i=0;i<parsed.rows.size();++i)if(parsed.rows[i].value=="VMware"&&parsed.rows[i].status=="indicator")found=true;
    require(found,"SMBIOS string-index decoding");
    std::vector<BYTE> bad=good;bad[9]=3;vm::Report badSize;vm::parseSmbios(badSize,bad);require(badSize.incomplete(),"short structure rejected");
    bad=good;bad.back()=1;vm::Report unterminated;vm::parseSmbios(unterminated,bad);require(unterminated.incomplete(),"unterminated string area rejected");
    bad=good;bad[4]=255;vm::Report oversized;vm::parseSmbios(oversized,bad);require(oversized.incomplete(),"oversized table rejected");
    vm::Report unknown;unknown.add("bios","x","B","test","unavailable","unsupported");require(unknown.incomplete(),"unsupported is incomplete");
    std::cout<<"Native tests: "<<checks<<" checks passed\n";return 0;
}catch(const std::exception&e){std::cerr<<e.what()<<"\n";return 1;}}
