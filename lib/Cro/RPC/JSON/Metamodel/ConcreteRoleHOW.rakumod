use v6.d;
unit role Cro::RPC::JSON::Metamodel::ConcreteRoleHOW:api<2>;

use nqp;
use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Metamodel::MethodContainer;
also does Cro::RPC::JSON::Metamodel::MethodContainer;

method re-settle-adhocs(Mu:U \r, \code_obj) {
    for code_obj.candidates.grep( * ~~ Cro::RPC::JSON::Method ) -> \cand {
        self.json-rpc-add-adhoc(r, $_, cand) for cand.json-rpc-adhocs;
    }
}

method add_method(Mu:U \r, \name, \code_obj) {
    if code_obj ~~ Cro::RPC::JSON::Method {
        # If a Cro::RPC::JSON::Method doesn't have json-rpc-name then it's an adhoc method
        self.json-rpc-add-method(r, $_, code_obj) with code_obj.json-rpc-name;
        self.re-settle-adhocs(r, code_obj);
    }
    nextsame;
}

method add_multi_method(Mu:U \r, \name, \code_obj) {
    self.re-settle-adhocs(r, code_obj);
    nextsame
}

method jrpc-auth {
    nqp::getattr(self, Metamodel::ConcreteRoleHOW, '@!roles')[0].HOW.jrpc-auth
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
