use v6.d;
unit role Cro::RPC::JSON::Metamodel::ClassHOW;

use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Metamodel::MethodContainer;
also does Cro::RPC::JSON::Metamodel::MethodContainer;

has %!jrpc-cache; # Maps JSON-RPC method names into actual method objects

method json-rpc-find-method( Mu \type, Str:D $name --> Code) is raw {
    my $meth := Nil;
    with %!jrpc-cache{$name} {
        $meth := $_;
#        note "### FOUND cached JSON-RPC method '$name': ", $meth.raku;
    }
    else {
        my $meth-name = type.^json-rpc-method-name($name);
#        note "??? Raku method name for '$name' is '{$meth-name // "*undef*"}'";
        with $meth-name {
            unless $meth := type.^find_method($_, :no_fallback) {
                fail X::Cro::RPC::JSON::MethodNotFound.new(
                    :msg("No JSON-RPC method '"
                         ~ $meth-name
                         ~ "' found on "
                         ~ type.^name
                    ))
            }
            unless $meth ~~ Cro::RPC::JSON::Method {
                fail X::Cro::RPC::JSON::MethodNotFound.new(
                    :msg("Method '"
                         ~ $meth-name
                         ~ "' found on "
                         ~ type.^name
                         ~ " as '"
                         ~ $meth-name
                         ~ "' but it's not a JSON-RPC implementation"
                    ))
            }
#            note "### FOUND JSON-RPC method '$meth-name': ", $meth.raku, " of ", $meth.^name;
            %!jrpc-cache{$name} := $meth;
        }
        else {
            fail X::Cro::RPC::JSON::MethodNotFound.new(
                :msg(type.^name
                     ~" doesn't implement JSON-RPC method '"
                     ~ $name ~"'"
                ))
        }
    }
    $meth
}