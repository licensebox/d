import licensebox;
import std.json;
import std.stdio;
void main(){
 auto c=new Client(parseJSON(`{"product":"your-product","keys":{"current":"YOUR_PUBLIC_KEY"}}`));
 scope(exit)c.close();
 try{writeln(c.requireModule("core").toString);}catch(LicenseboxException e){stderr.writeln(e.code,": ",e.msg);}
}
