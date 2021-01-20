use v6.d;
unit module Cro::RPC::JSON::Utils:api<2>;

use Cro::RPC::JSON::Metamodel::ClassHOW;
use Cro::RPC::JSON::Metamodel::ParametricRoleHOW;
use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Exception;

subset JRPCVersion is export of Str:D where "2.0";
subset JRPCId is export of Any where Int:D | Str:D;
subset JRPCErrCode is export of Int:D where * ~~ (-32700 | (-32603..-32600) | (-32099..-32000));

constant JRPC-DEFAULT-VERSION is export = "2.0";

constant JRPC-PARAMS = <async wsclose close last>;

# ---------------------- TRAIT CODE --------------------------

our sub apply-trait(Method:D \meth, %params?, Str :$name) {
    my $pkg = $*PACKAGE;
    my @unknown-params = %params.keys.grep: * !~~ any(JRPC-PARAMS);
    if +@unknown-params {
        my $suff = @unknown-params > 1 ?? "s" !! "";
        X::Cro::RPC::JSON::InternalError.new(
            :msg("Unsupported method modificator$suff: "
                 ~ @unknown-params.map({"'$_'"}).join(", ")
                 ~ " for method " ~ meth.name
                 ~ " in "
                 ~ $pkg.^name)).throw
    }
    given $pkg.HOW {
        when Metamodel::ClassHOW {
            $pkg.HOW does Cro::RPC::JSON::Metamodel::ClassHOW unless $pkg.HOW ~~ Cro::RPC::JSON::Metamodel::ClassHOW;
        }
        when Metamodel::ParametricRoleHOW {
            $pkg.HOW does Cro::RPC::JSON::Metamodel::ParametricRoleHOW
                unless $pkg.HOW ~~ Cro::RPC::JSON::Metamodel::ParametricRoleHOW;
        }
        default {
            X::Cro::RPC::JSON::InternalError.new(
                :msg("Can't declare a JSON-RPC method in module "
                     ~ $pkg.^name
                     ~ " of "
                     ~ $pkg.HOW.^name)).throw
        }
    }
    meth does Cro::RPC::JSON::Method unless meth ~~ Cro::RPC::JSON::Method;
    with $name {
        meth.set-json-rpc-name($name);
        $pkg.^json-rpc-add-method( $name, meth );
    }
    for %params.keys -> $mod {
        # It's OK to be explicit and use `is json-rpc("foo", :!async)`.
        $pkg.^json-rpc-add-adhoc($mod, meth) if ?%params{$mod};
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
