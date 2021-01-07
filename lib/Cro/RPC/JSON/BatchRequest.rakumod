use v6.d;
unit class Cro::RPC::JSON::BatchRequest;

use Cro::RPC::JSON::Request;
use Cro::RPC::JSON::Message;

also does Cro::RPC::JSON::Message;

has Cro::RPC::JSON::Request @.requests;
