use v6.d;
unit class Cro::RPC::JSON::BatchResponse:api<2>;

=begin pod
=head1 NAME

C<Cro::RPC::JSON::BatchResponse> - container of a list of responses to a batch request.

=head1 METHODS

=head2 <add(Cro::RPC::JSON::MethodResponse $resp)>

Adds a new response object to the list

=head2 C<jrpc-responses(--> Seq:D)>

Returns all response objects.

=end pod

use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::Message;

also does Cro::RPC::JSON::Message;

has Cro::RPC::JSON::MethodResponse @!jrpc-responses;
has Lock:D $!res-lock .= new;

method add(::?CLASS:D: Cro::RPC::JSON::MethodResponse:D $resp) {
    $!res-lock.lock;
    LEAVE $!res-lock.unlock;
    @!jrpc-responses.append: $resp;
}

method jrpc-responses( ::?CLASS:D: --> Seq:D ) {
    @!jrpc-responses.Seq
}

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|../JSON.md>,
L<C<Cro::RPC::JSON::Request>|Request.md>,
L<C<Cro::RPC::JSON::MethodResponse>|MethodResponse.md>,
L<C<Cro::RPC::JSON::BatchRequest>|BatchRequest.md>,

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
