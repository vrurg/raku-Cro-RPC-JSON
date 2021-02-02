use v6.d;
unit class Cro::RPC::JSON::ResponseSerializer::WebSocket:api<2>;

use Cro::Transform;
use Cro::WebSocket::Message;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Transform;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::ResponseSerializer;
use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::BatchResponse;
use Cro::RPC::JSON::Notification;
use JSON::Fast;

also is Cro::RPC::JSON::ResponseSerializer;
also does Cro::RPC::JSON::Transform;

method consumes { Cro::RPC::JSON::Message }
method produces { Cro::WebSocket::Message }

method transformer ( Supply $in ) {
    supply {
        whenever $in -> $msg {
            my $jresponse = "";
            given $msg {
                when Cro::RPC::JSON::MethodResponse {
                    $jresponse = .Hash unless .jrpc-request.is-notification;
                }
                when Cro::RPC::JSON::BatchResponse {
                    my @rlist;
                    for .jrpc-responses -> $resp {
                        @rlist.push( to-json($resp.Hash, :!pretty) ) unless $resp.jrpc-request.is-notification;
                    }
                    $jresponse = @rlist;
                }
                when Cro::RPC::JSON::Notification {
                    $jresponse = .json-body; # Notifications come in raw form, as emitted by user code
                }
                when Cro::WebSocket::Message {
                    emit $msg;
                    next;
                }
                default {
                    X::Cro::RPC::JSON::ServerError.new(
                        :msg("Cannot handle a request object of type " ~ .^name),
                        :code(JRPCBadReqType),
                        ).throw;
                }
            }
            QUIT {
                self!jsonify-exception($_, $.request);
            }
            emit Cro::WebSocket::Message.new(to-json($jresponse, :!pretty));
        }
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
