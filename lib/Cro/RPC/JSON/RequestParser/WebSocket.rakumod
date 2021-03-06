use v6.d;
unit class Cro::RPC::JSON::RequestParser::WebSocket:api<2>;

use Cro::Transform;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::RequestParser;

also is Cro::RPC::JSON::RequestParser;
also does Cro::Transform;

method consumes { Cro::RPC::JSON::Message }
method produces { Cro::RPC::JSON::Message }

method transformer(Supply:D $in) {
    supply {
        whenever $in -> $msg {
            emit self.body-to-request: await($msg.body);
        }
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>

