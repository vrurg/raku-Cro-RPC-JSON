use v6.d;

unit class Cro::RPC::JSON::ResponseSerializer::HTTP:api<2>;

use Cro::HTTP::Request;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Transform;
use Cro::RPC::JSON::Response;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::ResponseSerializer;
use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::BatchResponse;

also is Cro::RPC::JSON::ResponseSerializer;
also does Cro::RPC::JSON::Transform;

method consumes { Cro::RPC::JSON::Message }
method produces { Cro::RPC::JSON::Message }

method transformer ( Supply $in ) {
    supply {
        whenever $in -> $msg {
            my $jresponse = Cro::RPC::JSON::Response.new: :$.request;
            given $msg {
                when Cro::RPC::JSON::MethodResponse {
                    $jresponse.json-body = .jrpc-request.is-notification ?? "" !! .Hash;
                }
                when Cro::RPC::JSON::BatchResponse {
                    my @rlist;
                    for .jrpc-responses -> $resp {
                        @rlist.push( $resp.Hash ) unless $resp.jrpc-request.is-notification;
                    }
                    $jresponse.json-body = @rlist;
                }
                when Cro::HTTP::Message {
                    emit $msg;
                    next;
                }
                default {
                    self!jsonify-exception:
                        X::Cro::RPC::JSON::ServerError.new(
                            :msg("Cannot handle a request object of type " ~ .^name),
                            :code(JRPCBadReqType)),
                        $.request
                }
            }
            QUIT {
                self!jsonify-exception($_, $.request);
            }
            emit $jresponse;
        }
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>

