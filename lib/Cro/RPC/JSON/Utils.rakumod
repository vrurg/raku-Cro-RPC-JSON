use v6.d;
unit module Cro::RPC::JSON::Utils;

use Cro::RPC::JSON::Metamodel::ClassHOW;
use Cro::RPC::JSON::Metamodel::ParametricRoleHOW;
use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Exception;

subset JRPCVersion is export of Str:D where * ~~ "2.0";
subset JRPCId is export of Any where Int:D | Str:D;
subset JRPCMethod is export of Str:D where * ~~ /^ <!before rpc\.>/;
subset JRPCErrCode is export of Int:D where * ~~ (-32700 | (-32603..-32600) | (-32099..-32000));

# ---------------------- TRAIT CODE --------------------------

our sub apply-trait ( Str:D $name, Method:D \meth ) {
    my $pkg = $*PACKAGE;
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
    $pkg.^json-rpc-add-method( $name, meth );
    meth does Cro::RPC::JSON::Method unless meth ~~ Cro::RPC::JSON::Method;
    meth.set-json-rpc-name($name);
}

