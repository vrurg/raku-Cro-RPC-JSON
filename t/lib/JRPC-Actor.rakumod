use v6.d;
unit class JRPC-Actor;
use Cro::RPC::JSON:api<2>;
use Cro::RPC::JSON::Request:api<2>;
use Cro::RPC::JSON::Exception;
use Cro::HTTP::Server;
use Cro::HTTP::Router;

method foo(Int :$a, Str :$b) is json-rpc {
    return "$b and $a";
}

method by-request ( Cro::RPC::JSON::Request $req ) is json-rpc {
    { param-count => $req.params.elems }
}

proto method bar (|) is json-rpc { * }

multi method bar ( Str :$a! ) { "single named Str param" }
multi method bar ( Int $i, Num $n, Str $s ) { "Int, Num, Str positionals" }
multi method bar ( *%options ) { [ "slurpy hash:", %options ] }

method fail is json-rpc {
    my $ex = X::Cro::RPC::JSON::InvalidParams.new( msg => "I always fail" );
    $ex.throw;
}

method mortal is json-rpc {
    die "Simulate... well... something";
}

method non-json { "I won't be called!" }

method protocol is json-rpc { jrpc-protocol }
method is-async is json-rpc { jrpc-async }

