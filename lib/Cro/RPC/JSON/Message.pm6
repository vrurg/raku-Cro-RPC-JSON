use Cro::Message;
use Cro::RPC::JSON::Exception;

# The only version we support now.
subset JRPCVersion of Str where * ~~ "2.0";

subset JRPCId where * ~~ Str | Int;

subset JRPCMethod of Str where * ~~ /^ <!before rpc\.>/;

subset JRPCErrCode of Int where * ~~ (-32700 | (-32603..-32600) | (-32099..-32000));

class Cro::RPC::JSON::Request { ... }
class Cro::RPC::JSON::MethodResponse { ... }

role Cro::RPC::JSON::Message does Cro::Message is export {
    has JRPCVersion $.jsonrpc; # Version string
    has JRPCId $.id;
}

class Cro::RPC::JSON::BatchRequest does Cro::RPC::JSON::Message is export {
    has Cro::RPC::JSON::Request @.requests;
}

class Cro::RPC::JSON::Request does Cro::RPC::JSON::Message is export {
    has Cro::RPC::JSON::BatchRequest $.batch;
    has JRPCMethod $.method;
    has $.params;
    has %.data;         # Parsed body of the request
    has $.invalid;      # Will contain error message if request object was invalid

    submethod TWEAK {
        if not %!data<jsonrpc>:exists {
            $!invalid = "Missing required 'jsonrpc' key";
        }
        else {
            for %!data.keys -> $param {
                self."set-$param"( %!data{$param} );
                CATCH {
                    when X::Cro::RPC::JSON::InvalidRequest {
                        $!invalid = .msg;
                    }
                    default {
                        .rethrow
                    }
                }
            }
        }
    }

    method set-method ( $method ) {
        X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid method name: $method") ).throw
            unless $method ~~ JRPCMethod;
        $!method = $method;
    }

    method set-params ( $!params ) {}

    method set-jsonrpc ( $jsonrpc ) {
        X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid jsonrpc version: $jsonrpc") ).throw
            unless $jsonrpc ~~ JRPCVersion;
        $!jsonrpc = $jsonrpc;
    }

    method set-id ($id) {
        X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid id value: $id of type " ~ $id.WHO) ).throw
            unless $id ~~ JRPCId;
        $!id = $id;
    }

    method is-notification {
        not %!data<id>:exists
    }
}

class Cro::RPC::JSON::BatchResponse does Cro::Message is export {
    has Cro::RPC::JSON::MethodResponse @.responses;
}

class Cro::RPC::JSON::Error {
    has JRPCErrCode $.code is required;
    has Str $.message is required;
    has $.data is rw;

    method Hash ( --> Hash ) {
        (:$!code, :$!message, |($!data.defined ?? :$!data !! ())).Hash;
    }
}

class Cro::RPC::JSON::MethodResponse does Cro::RPC::JSON::Message is export {
    has $.result is rw;
    has Cro::RPC::JSON::Error $.error is rw;
    has Cro::RPC::JSON::Message $.request is rw;

    submethod TWEAK {
        $!jsonrpc //= "2.0";
    }

    method set-error ( *%err ) {
        $.error = Cro::RPC::JSON::Error.new( |%err );
    }

    method Hash ( --> Hash ) {
        (
            :$.jsonrpc,
            |( $.id.defined ?? :$.id !! () ),
            $.result.defined ?? :$.result !! (
                $.error.defined ?? 
                    :error($.error.Hash) !!
                    Cro::RPC::JSON::Error.new(
                        code => JRPCInternalError,
                        message => "method response contains neither result not error fields",
                        data => {
                            classification => "internal",
                            id => $.request.id,
                            method => $.request.method,
                        },
                    )
            ),
        ).Hash
    }
}

class Cro::RPC::JSON::Response does Cro::Message is export {
    has $.json-body is rw;
}
