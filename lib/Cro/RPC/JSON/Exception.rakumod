use v6.d;

constant JRPCParseError     is export = -32700;
constant JRPCInvalidRequest is export = -32600;
constant JRPCMethodNotFound is export = -32601;
constant JRPCInvalidParams  is export = -32602;
constant JRPCInternalError  is export = -32603;
constant JRPCErrGeneral     is export = -32000;
constant JRPCNoReqObject    is export = -32001;
# Something not available in a context. For example, $close argument is only available under WebSockets.
constant JRPCContext        is export = -32002;
constant JRPCBadReqType     is export = -32003;

role X::Cro::RPC::JSON is Exception {
    has Str $.msg; # Error text to report back to the client
    has $.data;    # Could be transferred into Cro::RPC::JSON::MethodResponse::Error .data attribute if set

    method message { $!msg }
    
    method jrpc-code { ... } # Error code of JSON RPC, https://www.jsonrpc.org/specification
    method http-code { ... } # Error code of HTTP request, https://www.jsonrpc.org/historical/json-rpc-over-http.html
}

class X::Cro::RPC::JSON::InvalidRequest  does X::Cro::RPC::JSON {
    method jrpc-code { JRPCInvalidRequest }
    method http-code { 200 }
}

class X::Cro::RPC::JSON::ParseError  does X::Cro::RPC::JSON {
    method jrpc-code { JRPCParseError }
    method http-code { 400 }
}

class X::Cro::RPC::JSON::MethodNotFound  does X::Cro::RPC::JSON {
    method jrpc-code { JRPCMethodNotFound }
    method http-code { 200 }
}

class X::Cro::RPC::JSON::InvalidParams  does X::Cro::RPC::JSON {
    method jrpc-code { JRPCInvalidParams }
    method http-code { 200 }
}

class X::Cro::RPC::JSON::InternalError  does X::Cro::RPC::JSON {
    method jrpc-code { JRPCInternalError }
    method http-code { 200 }
}

class X::Cro::RPC::JSON::ServerError  does X::Cro::RPC::JSON {
    has Int:D $.code is required where * ~~ -32099..-32000;
    method jrpc-code { $.code }
    method http-code { 200 }
}

#| Not application/json content type
class X::Cro::RPC::JSON::MediaType  does X::Cro::RPC::JSON {
    has $.content-type is required;
    submethod TWEAK {
        $!msg //= "Unsupported media type '{$!content-type.type-and-subtype}' in request";
    }
    method jrpc-code { -32700 }
    method http-code { 415 }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>

