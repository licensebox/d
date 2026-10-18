module adapter;
import licensebox;
import std.json;
import std.stdio;
import std.string;
JSONValue request;
extern(C) double clockCb(void* context) nothrow {try{return request["now"].floating;}catch(Throwable){try{return request["now"].integer;}catch(Throwable){return 0;}}}
extern(C) int bindingCb(void* context,char* output,size_t capacity) nothrow {
    try {
        auto s=request["binding"].str;if(s.length>=capacity)return 1;
        output[0..s.length]=s[];output[s.length]=0;return 0;
    }catch(Throwable){return 1;}
}
extern(C) void signinCb(void* context,const(char)* url,const(char)* code) nothrow {}
double number(JSONValue v){return v.type==JSONType.integer ? v.integer : v.floating;}
JSONValue run(JSONValue r){
    auto op=r["op"].str;auto product=r["product"].str;
    if(op=="derive")return JSONValue(deriveBinding(product,r["source"].str,r["raw_id"].str));
    if(op=="native")return JSONValue(nativeBinding(product));
    if(op=="verify")return verifyLease(r["token"].str,product,r["keys"],number(r["now"]));
    auto options=JSONValue(["product":r["product"],"keys":r["keys"],"server":r["server"],"directory":r["directory"],"version":JSONValue("conformance")]);
    if("ca_bundle" in r.object)options["ca_bundle"]=r["ca_bundle"];
    Callbacks cb;cb.clock=&clockCb;cb.onSignIn=&signinCb;
    if("binding" in r.object)cb.machineBinding=&bindingCb;
    auto client=new Client(options,cb);scope(exit)client.close();
    if(op=="require")return client.requireModule("module" in r.object ? r["module"].str : "core");
    if(op=="heartbeat" || op=="heartbeat-repeat" || op=="heartbeat-after-require"){
        auto name="module" in r.object ? r["module"].str : "core";
        if(op=="heartbeat-after-require")client.requireModule("core");
        if(op=="heartbeat-repeat")client.heartbeat(name);
        return client.heartbeat(name);
    }
    if(op=="repeat"){client.requireModule("core");return client.requireModule("core");}
    if(op=="sign_in")return client.signIn(3);
    if(op=="request")return client.requestAccess(["export"],"café – test");
    if(op=="record"){client.recordUsage("export",true,0.125);client.recordUsage("export",false,0.025);return JSONValue(null);}
    return client.call(op);
}
void main(){
    string input;foreach(line;stdin.byLine())input~=line.idup;
    request=parseJSON(input);
    try {writeln(JSONValue(["ok":JSONValue(true),"value":run(request)]).toString);}
    catch(LicenseboxException e){writeln(JSONValue(["ok":JSONValue(false),"error":JSONValue(e.code)]).toString);}
}
