unit role Cro::RPC::JSON::Metamodel::ConcreteRoleHOW;

use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Metamodel::MethodContainer;
also does Cro::RPC::JSON::Metamodel::MethodContainer;

method add_method(Mu:U \r, \name, \code_obj) {
    if code_obj ~~ Cro::RPC::JSON::Method {
        self.json-rpc-add-method(r, code_obj.json-rpc-name, code_obj);
    }
    nextsame;
}