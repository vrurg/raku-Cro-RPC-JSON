use v6.d;
unit role Cro::RPC::JSON::RequestParser::BodyStr:api<2>;

=begin pod

=head1 NAME

C<Cro::RPC::JSON::BodyStr> - role for converting a stringified requst body into a request object

=head1 ROLES

Does L<C<Cro::RPC::JSON::Requestish>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.4/docs/md/Cro/RPC/JSON/Requestish.md>

=end pod

use Cro::HTTP::Request;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Request;
use Cro::RPC::JSON::Requestish;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::BatchRequest;
use Cro::HTTP::Router;
use JSON::Fast;

also does Cro::RPC::JSON::Requestish;

method body-to-request(Str:D $body --> Cro::RPC::JSON::Message:D) {
    my $json;
    {
        CATCH { default { X::Cro::RPC::JSON::ParseError.new( :msg(.payload) ).throw } }
        $json = from-json( $body );
    }
    my $jrpc-request;
    given $json {
        my $request = self.request;
        when Array {
            #note "DATA {$_.WHO}:", $_;
            $jrpc-request = Cro::RPC::JSON::BatchRequest.new: :$request;
            .map: {
                #note "New REQ from ", $_;
                $jrpc-request.add: Cro::RPC::JSON::Request.new( :data($_), :batch($jrpc-request), :$request )
            };
        }
        when Hash {
            #note "SINGLE REQUEST";
            $jrpc-request = Cro::RPC::JSON::Request.new( :data($_), :$request );
        }
        default {
            die "Unsupported JSON RPC data type " ~ .^name;
        }
    }
    $jrpc-request
}

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.4/docs/md/Cro/RPC/JSON.md>,
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.4/docs/md/Cro/RPC/JSON/Request.md>,
L<C<Cro::RPC::JSON::BatchRequest>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.4/docs/md/Cro/RPC/JSON/BatchRequest.md>,
L<Cro|https://cro.services>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
