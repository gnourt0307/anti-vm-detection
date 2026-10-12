#include "vmtool.h"
namespace vm {
void scanTiming(Report& r){LARGE_INTEGER freq,start,end;if(!QueryPerformanceFrequency(&freq)||freq.QuadPart<=0){r.add("timing","timing.qpc","I","Windows timer","QPC unavailable","unsupported");return;}
    r.add("timing","timing.frequency","I","Windows timer",number(freq.QuadPart));
    std::vector<uint64_t> cp,sleep,raw;DWORD_PTR previous=SetThreadAffinityMask(GetCurrentThread(),1);
    r.add("timing","timing.affinity","I","Windows scheduler",previous?"Pinned to logical CPU 0 for sampling; restored afterward":"Affinity unavailable; measurements may migrate");
    bool valid=true;uint32_t c[4];
    for(unsigned i=0;i<101;++i){if(!QueryPerformanceCounter(&start)){valid=false;break;}for(unsigned j=0;j<64;++j)cpuid(0,0,c);if(!QueryPerformanceCounter(&end)||end.QuadPart<start.QuadPart){valid=false;break;}cp.push_back((end.QuadPart-start.QuadPart)*1000000000ULL/freq.QuadPart/64);}
    for(unsigned i=0;valid&&i<25;++i){DWORD tick=GetTickCount();if(!QueryPerformanceCounter(&start)){valid=false;break;}Sleep(10);if(!QueryPerformanceCounter(&end)||end.QuadPart<start.QuadPart){valid=false;break;}sleep.push_back((end.QuadPart-start.QuadPart)*1000000ULL/freq.QuadPart);raw.push_back((DWORD)(GetTickCount()-tick));}
    if(previous&&!SetThreadAffinityMask(GetCurrentThread(),previous))r.error("timing","timing.restore-affinity",GetLastError());
    if(!valid){r.error("timing","timing.sample",ERROR_INVALID_DATA,"QPC failed or moved backwards");return;}
    std::string samples;for(size_t i=0;i<cp.size();++i){if(i)samples+=",";samples+=number(cp[i]);}r.add("timing","timing.cpuid-ns-raw","I","QPC/CPUID",samples);
    samples.clear();for(size_t i=0;i<sleep.size();++i){if(i)samples+=",";samples+=number(sleep[i])+"/"+number(raw[i]);}r.add("timing","timing.sleep-us-tick-ms-raw","I","QPC/GetTickCount/Sleep",samples);
    std::sort(cp.begin(),cp.end());std::sort(sleep.begin(),sleep.end());
    r.add("timing","timing.cpuid-ns","I","QPC/CPUID","min="+number(cp.front())+" median="+number(cp[50])+" p95="+number(cp[95])+" max="+number(cp.back()));
    r.add("timing","timing.sleep10-us","I","QPC/Sleep","min="+number(sleep.front())+" median="+number(sleep[12])+" max="+number(sleep.back()));
    r.add("timing","timing.limitations","I","measurement protocol","101 batches of 64 CPUID(0); 25 Sleep(10) samples. Warm host/guest, repeat 5 times. No VM threshold. Power, load, timer resolution, VBS, migration and scheduling confound results.");
}
}
