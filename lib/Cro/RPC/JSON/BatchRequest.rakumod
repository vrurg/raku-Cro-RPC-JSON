use v6.d;
unit class Cro::RPC::JSON::BatchRequest:api<2>;

=begin pod
=head1 NAME

C<Cro::RPC::JSON::BatchRequest> - container for requests received as members of a L<batch request|https://www.jsonrpc.org/specification#batch>

=head1 DESCRIPTION

This class must not be manipulated directly under normal circumstances.

=head1 ATTRIBUTES

=item C<$.pending> - number of pending requests, i.e. those for which responses were not completed yet (see L<C<Cro::RPC::JSON::MethodResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.902/docs/md/Cro/RPC/JSON/MethodResponse.md>)
=item C<Promise:D $.completed> – this promise is kept when all responses are completed
=item L<C<Cro::RPC::JSON::BatchResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.902/docs/md/Cro/RPC/JSON/BatchResponse.md>C< $.jrpc-response> – batch response object paired to this batch request

=head1 METHODS

=head2 C<jrpc-requests(--> Seq:D)>

All contained requests

=head2 C<respond()>

If this batch request is complete, i.e. all of related responses are completed, then it will be emitted.

=end pod

use Cro::RPC::JSON::Request;
use Cro::RPC::JSON::BatchResponse;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Requestish;

also does Cro::RPC::JSON::Message;
also does Cro::RPC::JSON::Requestish;

has Cro::RPC::JSON::Request @!jrpc-requests;
has Lock:D $!req-lock .= new;
has atomicint $.pending = 0;
has Promise:D $.completed .= new;
has Cro::RPC::JSON::BatchResponse:D $.jrpc-response .= new(request => $!request);

method add(::?CLASS:D: Cro::RPC::JSON::Request:D $req) {
    $!req-lock.lock;
    LEAVE $!req-lock.unlock;
    @!jrpc-requests.append: $req;
    ++⚛$!pending;
}

method complete(::?CLASS:D: Cro::RPC::JSON::Request:D $req --> Bool) {
#    note "--- completing request #", $req.id;
    my $remaining = --$!pending;
    if $remaining < 0 {
        die "A batch request is already completed; unexpected request id=" ~ $req.id;
    }
    elsif $remaining == 0 {
        $!completed.keep;
        return True;
    }
    False
}

method jrpc-requests(::?CLASS:D: --> Seq:D) {
    @!jrpc-requests.Seq }

method respond {
    if $!completed {
       emit $!jrpc-response
    }
}

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.902/docs/md/Cro/RPC/JSON.md>,
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.902/docs/md/Cro/RPC/JSON/Request.md>,
L<C<Cro::RPC::JSON::MethodResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.902/docs/md/Cro/RPC/JSON/MethodResponse.md>,
L<C<Cro::RPC::JSON::BatchRequest>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.902/docs/md/Cro/RPC/JSON/BatchRequest.md>,

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
