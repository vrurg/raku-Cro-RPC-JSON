use v6.d;
unit module Cro::RPC::JSON::Utils:api<2>;

use nqp;
use Cro::RPC::JSON::Metamodel::ClassHOW;
use Cro::RPC::JSON::Metamodel::ParametricRoleHOW;
use Cro::RPC::JSON::Metamodel::MethodContainer;
use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Exception;

subset JRPCVersion is export of Str:D where "2.0";
subset JRPCId is export of Any where Int:D | Str:D;
subset JRPCErrCode is export of Int:D where * ~~ (-32700 | (-32603..-32600) | (-32099..-32000));

constant JRPC-DEFAULT-VERSION is export = "2.0";

constant JRPC-ADHOC-PARAMS = any <async wsclose close last>;
constant JRPC-HELPER-PARAMS = any <auth>;
constant JRPC-ALL-PARAMS = any(JRPC-ADHOC-PARAMS, JRPC-HELPER-PARAMS);

# ---------------------- TRAIT CODE --------------------------

my sub HOW-onto-type( Mu:U \pkg) {
    my $how := pkg.HOW;
    # Both our ClassHOW and ParametricRoleHOW do MethodContainer role
    unless $how ~~ Cro::RPC::JSON::Metamodel::MethodContainer {
        given $how {
            when Metamodel::ClassHOW {
                $how does Cro::RPC::JSON::Metamodel::ClassHOW;
            }
            when Metamodel::ParametricRoleHOW {
                $how does Cro::RPC::JSON::Metamodel::ParametricRoleHOW;
            }
            default {
                X::Cro::RPC::JSON::InternalError.new(
                    :msg( "Can't declare JSON-RPC methods in module "
                          ~ pkg.^name
                          ~ " of "
                          ~ $how.^name )).throw
            }
        }
    }
}

our sub apply-json-rpc-trait(Method:D \meth, %params?, Str :$name is copy) {
    my $pkg = $*PACKAGE;
    my @unknown-params = %params.keys.grep: * !~~ JRPC-ALL-PARAMS;
    if +@unknown-params {
        my $suff = @unknown-params > 1 ?? "s" !! "";
        X::Cro::RPC::JSON::InternalError.new(
            :msg("Unsupported method modificator$suff: "
                 ~ @unknown-params.map({"'$_'"}).join(", ")
                 ~ " for method " ~ meth.name
                 ~ " in "
                 ~ $pkg.^name)).throw
    }
    HOW-onto-type($pkg);
    meth does Cro::RPC::JSON::Method unless meth ~~ Cro::RPC::JSON::Method;
    meth.json-rpc-auth = $_ with %params<auth>;
    my $is-adhoc = False;
    for %params.keys.grep(JRPC-ADHOC-PARAMS) -> $mod {
        once $is-adhoc = True;
        # It's OK to be explicit and use `is json-rpc("foo", :!async)`.
        $pkg.^json-rpc-add-adhoc($mod, meth) if ?%params{$mod};
    }
    $name //= meth.name unless $is-adhoc;
    with $name {
        meth.set-json-rpc-name($name);
        $pkg.^json-rpc-add-method( $name, meth );
    }
}

our sub apply-actor-trait(Mu:U \typeobj, %params?) {
    HOW-onto-type(typeobj);
    typeobj.HOW.jrpc-auth = $_ with %params<auth>;
}

sub json-rpc-mro(Mu \type, Bool :$roles --> List()) {
    type.^mro(:$roles).grep: { .HOW ~~ Cro::RPC::JSON::Metamodel::MethodContainer }
}

sub json-rpc-adhoc-methods(Mu \type, Str:D $mod --> List()) is export {
    my $adhocs := nqp::list();
    for json-rpc-mro(type, :roles) -> Mu \typeobj {
        nqp::push($adhocs, $_) for typeobj.^json-rpc-adhoc-methods($mod, :local);
    }
    nqp::hllize($adhocs)
}

sub json-rpc-find-method(Mu \type, Str:D $method --> Code) is export {
    for json-rpc-mro(type) -> Mu \typeobj {
        return $_ with typeobj.^json-rpc-find-method($method, :local);
    }
}

sub json-rpc-auth(Mu \type) is export {
    for json-rpc-mro(type, :roles) -> Mu \typeobj {
        return $_ with typeobj.^json-rpc-auth
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
