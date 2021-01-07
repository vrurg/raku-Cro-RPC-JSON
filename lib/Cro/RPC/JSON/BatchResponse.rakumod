use v6.d;
unit class Cro::RPC::JSON::BatchResponse;

use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::Message;

also does Cro::RPC::JSON::Message;

has Cro::RPC::JSON::MethodResponse @.responses;
