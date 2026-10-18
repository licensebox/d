import licensebox;
import std.json;
import std.stdio;
void main(){
 assert(deriveBinding("demo","linux-machine-id","12345678123456789abc1234567890ab")=="m1:linux-machine-id:783b8906a4af61095e68f3f0b4468a953be69ddd7afcf35850b501a7361f309e");
 auto c=new Client(parseJSON(`{"product":"demo","keys":{"k":"A6EHv_POEL4dcN0Y50vAmWfk1jCbpQ1fHdyGZBJVMbg"},"directory":"build/test-state"}`));
 auto aliasClient=c;
 try{c.status();assert(false);}catch(LicenseboxException e){assert(e.code=="not_signed_in");}
 c.logout();c.close();aliasClient.close();
 try{aliasClient.status();assert(false);}catch(LicenseboxException e){assert(e.code=="invalid_argument");}
 writeln("binding checks passed");
}
