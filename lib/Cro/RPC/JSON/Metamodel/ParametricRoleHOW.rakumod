use v6.d;
unit role Cro::RPC::JSON::Metamodel::ParametricRoleHOW:api<2>;

use Cro::RPC::JSON::Metamodel::MethodContainer;
use Cro::RPC::JSON::Metamodel::ClassHOW;
use Cro::RPC::JSON::Metamodel::ConcreteRoleHOW;

also does Cro::RPC::JSON::Metamodel::MethodContainer;

# Mark the class we're applied to as a JSON-RPC class.
method specialize_with (Mu \r, Mu:U \conc, Mu $, @params, | ) is raw {
    my \obj = @params[0];
    obj.HOW does Cro::RPC::JSON::Metamodel::ClassHOW
        unless obj.HOW ~~ Cro::RPC::JSON::Metamodel::ClassHOW;
    conc.HOW does Cro::RPC::JSON::Metamodel::ConcreteRoleHOW;
    callsame();
    conc
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
