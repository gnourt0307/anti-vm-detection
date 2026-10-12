#include "vmtool.h"
namespace vm {
void scanGraphics(Report& r){DISPLAY_DEVICEW d={};d.cb=sizeof(d);DWORD i=0;
    for(;EnumDisplayDevicesW(NULL,i,&d,0);++i){std::string id="display."+utf8(d.DeviceName);std::string v=utf8(d.DeviceString)+" id="+utf8(d.DeviceID)+" registry="+utf8(d.DeviceKey);
        r.add("graphics",id,"G","graphics device/driver",v,marker(v)?"indicator":"observed","Host: documented 3D acceleration option; keep compatible graphics driver","no (scan)","power off for host change","Disabling acceleration changes capabilities/performance; VMware identity can remain");
        DEVMODEW m={};m.dmSize=sizeof(m);if(EnumDisplaySettingsW(d.DeviceName,ENUM_CURRENT_SETTINGS,&m))r.add("graphics",id+".mode","G","display configuration",number(m.dmPelsWidth)+"x"+number(m.dmPelsHeight)+" bpp="+number(m.dmBitsPerPel)+" Hz="+number(m.dmDisplayFrequency));
        else r.add("graphics",id+".mode","G","Windows","No active display mode","absent");
        d.cb=sizeof(d);
    }r.add("graphics","display.count","G","Windows",number(i));
}
}
