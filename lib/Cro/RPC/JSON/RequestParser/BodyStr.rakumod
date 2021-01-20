use v6.d;
unit role Cro::RPC::JSON::RequestParser::BodyStr:api<2>;

use Cro::HTTP::Request;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Request;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::BatchRequest;
use JSON::Fast;

method body-to-request(Str:D $body --> Cro::RPC::JSON::Message:D) {
    my $json;
    {
        CATCH { default { X::Cro::RPC::JSON::ParseError.new( :msg(.payload) ).throw } }
        $json = from-json( $body );
    }
    #note "JSON PARSED: ", $json.perl;
    my $jrpc-request;
    given $json {
        when Array {
            #note "DATA {$_.WHO}:", $_;
            $jrpc-request = Cro::RPC::JSON::BatchRequest.new;
            .map: {
                #note "New REQ from ", $_;
                $jrpc-request.add: Cro::RPC::JSON::Request.new( :data($_), :batch($jrpc-request) )
            };
        }
        when Hash {
            #note "SINGLE REQUEST";
            $jrpc-request = Cro::RPC::JSON::Request.new( :data($_) );
        }
        default {
            die "Unsupported JSON RPC data type " ~ .^name;
        }
    }
    $jrpc-request
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
