#include "vmtool.h"
#include <iostream>
#include <objbase.h>
#include <shellapi.h>
static_assert(sizeof(void*)==4,"Build this toolkit for x86");
int main(){int argc=0;LPWSTR*argv=CommandLineToArgvW(GetCommandLineW(),&argc);if(!argv)return 1;
    std::wstring out=L"",module=L"all";bool bad=false;
    for(int i=1;i<argc;++i){std::wstring a=argv[i];if(a==L"--out"&&i+1<argc)out=argv[++i];else if(a==L"--module"&&i+1<argc)module=argv[++i];else if(a==L"--help"){std::cout<<"vmtool --out NEW.xml [--module all|cpu|hardware|bios|registry|network|storage|graphics|services|timing|compatibility|consistency]\nExit: 0 complete, 2 partial, 1 invocation/output failure. Read-only.\n";LocalFree(argv);return 0;}else bad=true;}
    LocalFree(argv);if(bad||out.empty()){std::cerr<<"Use --help. --out must name a new report.\n";return 1;}
    struct Module{const wchar_t* name;void(*scan)(vm::Report&);};
    Module mods[]={{L"compatibility",vm::scanCompatibility},{L"cpu",vm::scanCpu},{L"bios",vm::scanBios},{L"registry",vm::scanRegistry},{L"hardware",vm::scanHardware},{L"network",vm::scanNetwork},{L"storage",vm::scanStorage},{L"graphics",vm::scanGraphics},{L"services",vm::scanServices},{L"timing",vm::scanTiming},{L"consistency",vm::scanConsistency}};
    vm::Report r;bool found=false;
    for(size_t i=0;i<sizeof(mods)/sizeof(mods[0]);++i)if(module==L"all"||module==mods[i].name){found=true;std::cout<<"Scanning "<<vm::utf8(mods[i].name)<<"...\n";try{mods[i].scan(r);}catch(const std::exception&e){r.error(vm::utf8(mods[i].name),"exception."+vm::utf8(mods[i].name),ERROR_INVALID_DATA,e.what());}}
    if(!found){std::cerr<<"Unknown module\n";return 1;}
    if(!vm::writeReport(r,out)){std::cerr<<"Cannot publish report (existing file, missing directory or I/O failure).\n";return 1;}
    std::cout<<r.rows.size()<<" observations; "<<(r.incomplete()?"partial coverage":"collection completed")<<". No undetectability conclusion.\n";return r.incomplete()?2:0;
}
