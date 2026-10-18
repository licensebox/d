module licensebox;
import std.json;
import std.string : toStringz, fromStringz, indexOf, stripRight;
import core.stdc.stdlib : free;

class LicenseboxException : Exception {
    string code;
    this(string code, string detail) { this.code=code; super(detail); }
}
extern(C) {
    alias SignInCallback = void function(void*, const(char)*, const(char)*) nothrow;
    alias ClockCallback = double function(void*) nothrow;
    alias BindingCallback = int function(void*, char*, size_t) nothrow;
    alias CancelledCallback = int function(void*) nothrow;
    struct Callbacks {
        void* context;
        SignInCallback onSignIn;
        ClockCallback clock;
        BindingCallback machineBinding;
        CancelledCallback cancelled;
    }
    private int lb_client_create_json(const(char)*, const(Callbacks)*, out void*);
    private int lb_client_call_json(void*, const(char)*, const(char)*, out char*);
    private void lb_client_destroy(void*);
    private void lb_free(void*);
    private const(char)* lb_result_code(int);
    private const(char)* lb_error_code(void*);
    private const(char)* lb_error_message(void*);
    private int lb_derive_binding(const(char)*, const(char)*, const(char)*, char*, size_t);
    private int lb_native_binding(const(char)*, char*, size_t);
    private int lb_verify_lease_json(const(char)*, const(char)*, const(char)*, double, out char*);
}
private string valid(string value) {
    if(value.indexOf('\0')>=0) throw new LicenseboxException("invalid_argument","NUL in argument");
    return value;
}
private string text(const(char)* p) { return p is null ? "" : fromStringz(p).idup; }
private void check(int result, void* handle=null) {
    if(!result)return;
    auto code=text(lb_result_code(result)); auto detail=code;
    if(handle !is null && code!="invalid_argument") {
        auto saved=text(lb_error_code(handle)); if(saved!="ok")code=saved;
        detail=text(lb_error_message(handle));
    }
    throw new LicenseboxException(code,detail);
}
private JSONValue owned(char* p) {
    if(p is null)throw new LicenseboxException("protocol_error","missing native result");
    scope(exit)lb_free(p);
    return parseJSON(text(p));
}
/// Shared reference ownership. Close is idempotent and closes every alias.
/// Callback context is borrowed and must outlive this client. Callbacks must
/// not throw or reenter. Clock/binding callbacks are trusted platform/test seams.
class Client {
    private void* handle;
    private Callbacks callbacks;
    private bool busy;
    this(JSONValue options, Callbacks callbacks=Callbacks.init) {
        this.callbacks=callbacks;
        check(lb_client_create_json(toStringz(options.toString), &this.callbacks, handle));
    }
    ~this() { if(handle !is null)lb_client_destroy(handle); }
    void close() { synchronized(this) {
        if(busy)throw new LicenseboxException("invalid_argument","callback reentry");
        if(handle !is null){lb_client_destroy(handle);handle=null;}
    }}
    JSONValue call(string operation, JSONValue args=JSONValue.init) { synchronized(this) {
        valid(operation);
        if(handle is null || busy)throw new LicenseboxException("invalid_argument","closed client or callback reentry");
        busy=true;scope(exit)busy=false;
        char* output;
        auto argument=args.type==JSONType.null_ ? "{}" : args.toString;
        auto result=lb_client_call_json(handle,toStringz(operation),toStringz(argument),output);
        if(result){lb_free(output);check(result,handle);}
        return owned(output);
    }}
    JSONValue lease(){return call("lease");}
    JSONValue requireModule(string name){return call("require",JSONValue(["module":JSONValue(valid(name))]));}
    JSONValue heartbeat(string name){return call("heartbeat",JSONValue(["module":JSONValue(valid(name))]));}
    JSONValue status(){return call("status");}
    JSONValue signIn(double timeout=0){return call("sign_in",JSONValue(["timeout":JSONValue(timeout)]));}
    void logout(){call("logout");}
    JSONValue modules(){return call("modules");}
    JSONValue requests(){return call("requests");}
    JSONValue requestAccess(string[] names,string note=""){
        JSONValue[] values;foreach(name;names)values~=JSONValue(valid(name));
        return call("request",JSONValue(["modules":JSONValue(values),"note":JSONValue(valid(note))]));
    }
    string accessLink(){return call("access-link").str;}
    void recordUsage(string command,bool success,double elapsed){
        call("record",JSONValue(["command":JSONValue(valid(command)),"success":JSONValue(success),"elapsed":JSONValue(elapsed)]));
    }
}
string deriveBinding(string product,string source,string rawId){
    valid(product);valid(source);
    auto raw=rawId;while(raw.length && raw[$-1]=='\0')raw=raw[0..$-1];
    if(raw.indexOf('\0')>=0)throw new LicenseboxException("identity_unavailable","invalid identifier");
    char[128] output;
    check(lb_derive_binding(toStringz(product),toStringz(source),toStringz(raw),output.ptr,output.length));
    return text(output.ptr);
}
string nativeBinding(string product){
    valid(product);char[128] output;
    check(lb_native_binding(toStringz(product),output.ptr,output.length));return text(output.ptr);
}
JSONValue verifyLease(string token,string product,JSONValue keys,double now){
    valid(token);valid(product);char* output;
    auto result=lb_verify_lease_json(toStringz(token),toStringz(product),toStringz(keys.toString),now,output);
    if(result){lb_free(output);check(result);}
    return owned(output);
}
