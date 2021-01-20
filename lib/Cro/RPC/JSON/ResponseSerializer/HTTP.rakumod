use v6.d;

unit class Cro::RPC::JSON::ResponseSerializer::HTTP:api<2>;

use Cro::HTTP::Request;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Transform;
use Cro::RPC::JSON::Response;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::BatchResponse;

also does Cro::RPC::JSON::Transform;

method consumes { Cro::RPC::JSON::Message }
method produces { Cro::RPC::JSON::Message }

method transformer ( Supply $in ) {
    supply {
        whenever $in -> $msg {
            my $jresponse = Cro::RPC::JSON::Response.new;
            given $msg {
                when Cro::RPC::JSON::MethodResponse {
                    $jresponse.json-body = .request.is-notification ?? "" !! .Hash;
                }
                when Cro::RPC::JSON::BatchResponse {
                    my @rlist;
                    for .responses -> $resp {
                        @rlist.push( $resp.Hash ) unless $resp.request.is-notification;
                    }
                    $jresponse.json-body = @rlist;
                }
                default {
                    self!jsonify-exception:
                        X::Cro::RPC::JSON::ServerError.new(
                            :msg("Cannot handle a request object of type " ~ .^name),
                            :code(JRPCBadReqType))
                }
            }
            QUIT {
                self!jsonify-exception($_);
            }
            emit $jresponse;
        }
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>

