use v6.d;
unit module Cro::RPC::JSON::Constants;

# v2021.10.87.gd.38852628 is when .^mro(:roles) started returning paramteric groups instead of concretiztions
constant USE_MRO_CONCRETIZATIONS is export = $*RAKU.compiler.version >= v2021.10.87.gd.38852628;