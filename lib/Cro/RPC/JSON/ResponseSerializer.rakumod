use v6.d;

unit class Cro::RPC::JSON::ResponseSerializer;

use Cro::Transform;
use Cro::HTTP::Request;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Response;
use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::BatchResponse;

also does Cro::Transform;

method consumes { Cro::RPC::JSON::Message }
method produces { Cro::RPC::JSON::Response }

method transformer ( Supply $in ) {
    supply {
        whenever $in -> $msg {
            my $jresponse = Cro::RPC::JSON::Response.new;
            given $msg {
#                note "RESPONSE SERIALIZATION OF ", $msg.raku;
                when Cro::RPC::JSON::MethodResponse {
                    $jresponse.json-body = .request.is-notification ?? "" !! .Hash;
                }
                when Cro::RPC::JSON::BatchResponse {
                    my @rlist;
                    for .responses -> $resp {
                        #note "GEN RESP FROM:", $resp;
                        @rlist.push( $resp.Hash ) unless $resp.request.is-notification;
                    }
                    $jresponse.json-body = @rlist;
                }
                default {
                    X::Cro::RPC::JSON::ServerError.new(
                        msg => "Cannot handle a request object of type " ~ .^name
                        ).throw;
                }
            }
            emit $jresponse;
        }
    }
}

# Copyright (c) 2018, Vadim Belman <vrurg@cpan.org>

