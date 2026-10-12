#include <winsock2.h>
#include "vmtool.h"
#include <iphlpapi.h>
#include <iomanip>
namespace vm {
void scanNetwork(Report& r) {
    ULONG n=16*1024;std::vector<BYTE>b(n);ULONG e=ERROR_BUFFER_OVERFLOW;
    for(int attempt=0;attempt<3&&e==ERROR_BUFFER_OVERFLOW;++attempt){b.resize(n);e=GetAdaptersAddresses(AF_UNSPEC,GAA_FLAG_SKIP_ANYCAST|GAA_FLAG_SKIP_MULTICAST|GAA_FLAG_SKIP_DNS_SERVER,NULL,(IP_ADAPTER_ADDRESSES*)&b[0],&n);if(n>16*1024*1024){e=ERROR_NOT_ENOUGH_MEMORY;break;}}
    if(e==ERROR_NO_DATA){r.add("network","network.adapters","E","Windows","No adapters","absent");return;}
    if(e!=NO_ERROR){r.error("network","network.adapters",e);return;}
    for(IP_ADAPTER_ADDRESSES*a=(IP_ADAPTER_ADDRESSES*)&b[0];a;a=a->Next){std::string id="net."+std::string(a->AdapterName);std::string desc=a->Description?utf8(a->Description):"";
        r.add("network",id+".description","E","virtual NIC/driver",desc,marker(desc)?"indicator":"observed","Host: supported adapter selection; guest: compatible signed driver","host administrator (change)","power off (hardware change)","Changing adapter can remove connectivity; preserve MAC and network configuration");
        r.add("network",id+".friendly-name","E","Windows connection configuration",a->FriendlyName?utf8(a->FriendlyName):"");
        std::ostringstream mac;for(ULONG j=0;j<a->PhysicalAddressLength&&j<MAX_ADAPTER_ADDRESS_LENGTH;++j){if(j)mac<<":";mac<<std::hex<<std::setw(2)<<std::setfill('0')<<(unsigned)a->PhysicalAddress[j];}
        std::string m=mac.str();bool oui=m.find("00:05:69")==0||m.find("00:0c:29")==0||m.find("00:1c:14")==0||m.find("00:50:56")==0;
        r.add("network",id+".mac","E","virtual NIC configuration",m,oui?"indicator":"observed","Host: Workstation supported MAC assignment; no automatic changes","host write permission","adapter reconnect","OUI alone is weak evidence; collision, DHCP and licensing impact");
        r.add("network",id+".metadata","E","Windows", "type="+number(a->IfType)+" status="+number(a->OperStatus)+" mtu="+number(a->Mtu));
    }
}
}
