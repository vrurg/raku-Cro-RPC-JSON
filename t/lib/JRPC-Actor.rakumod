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

method paramless is json-rpc {
    "a method with no parameters"
}

method fail is json-rpc {
    my $ex = X::Cro::RPC::JSON::InvalidParams.new( msg => "I always fail" );
    $ex.throw;
}

method cro-request is json-rpc {
    given request {
        %(
            request => .^name,
            path => .path,
            method => .method,
        )
    }
}

method mortal is json-rpc {
    die "Simulate... well... something";
}

method non-json { "I won't be called!" }

method protocol is json-rpc { jrpc-protocol }
method is-async is json-rpc { jrpc-async }

class IntraFoo {
    has Str $.name;
    has Int $.count;
}

class IntraBar {
    has Bool $.flag;
    has %.map;
}

method return-obj is json-rpc {
    IntraFoo.new(:count(42), :name('The Answer'))
}

method accept-obj(IntraFoo:D $foo) is json-rpc {
    $foo.raku
}

method accept-obj-array(IntraFoo:D @foo) is json-rpc {
    @foo.raku
}

method accept-obj-hash(IntraFoo:D %foo) is json-rpc {
    %foo.WHAT
        .raku
        ~ " = \{ "
        ~ %foo.keys.sort
            .map({ $_ ~ " => " ~ %foo{$_}.raku })
            .join(", ")
        ~ " \}"
}

method accept-obj-params(IntraFoo:D @foo, IntraBar:D $bar, *@pos) is json-rpc {
    @foo.raku ~ "\n" ~ $bar.raku ~ "\n" ~ @pos.raku
}

proto method accept-obj-multi(IntraFoo:D, |) is json-rpc {*}
multi method accept-obj-multi(IntraFoo:D, Str:D $str) {
    "Str candidate " ~ $str
}
multi method accept-obj-multi(IntraFoo:D, Int:D $int) {
    "Int candidate " ~ $int
}
multi method accept-obj-multi(IntraFoo:D, Bool:D $flag) {
    "Bool candidate " ~ $flag
}
