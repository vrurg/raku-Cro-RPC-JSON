use v6.d;
unit class Cro::RPC::JSON::Request:api<2>;

=begin pod

=head1 NAME

C<Cro::RPC::JSON::Request> - prepared JSON-RPC request object

=head1 ROLES

Does L<C<Cro::RPC::JSON::Message>|Message.md>,
L<C<Cro::RPC::JSON::Requestish>|Requestish.md>

=head1 ATTRIBUTES

=item C<$.jsonrpc> - JSON-RPC version. Currently this attribute always contains I<"2.0">
=item C<$.id> - JSON-RPC request id. Undefined if the request is a L<notification|https://www.jsonrpc.org/specification#notification>.
=item C<Str $.method> – request method name
=item C<$.params> – request parameters as parsed from JSON-RPC request object C<params> key
=item C<%.data> – parsed full request JSON object.
=item C<Str $.invalid> – undefined for valid requests. Otherwise contains error message explaining the cause.
=item C< $.batch> - if request is part of a L<batch request|https://www.jsonrpc.org/specification#batch>
    then this attribute points to corresponding
    L<C<Cro::RPC::JSON::BatchRequest>|BatchRequest.md> object

=head1 METHODS

=head2 C<set-jsonrpc($jsonrpc)>, C<set-id($id)>, C<set-method(Str:D $method)>, C<set-params($params)>

Set corresponding attributes.

C<set-jsonrpc> and C<set-id> throw C<X::Cro::RPC::JSON::InvalidRequest> if supplied value is invalid.

=head2 C<is-notification(--> Bool:D)>

Returns I<True> if request is a L<notification|https://www.jsonrpc.org/specification#notification>, i.e. when C<id> key
is not specified.

=head2 C<jrpc-response(|c)>

Returns a L<C<Cro::RPC::JSON::MethodResponse>|MethodResponse.md>
object paired with the current request. Most of the time this method must be given preference over creating a method
response object manually.

=head2 C<proto respond()>

This method is what must be used to respond to a request. It creates a new response object if necessary, completes it,
and them calls L<C<emit>|https://docs.raku.org/routine/emit> with it.

=head3 C<multi respond(Any:D $data)>

Takes C<$data> and sets it as the result of current request response.

=head3 C<multi respond(Exception:D :$exception)>

Takes an exception and produces correct error response from it.

=head3 C<multi respond()>

If request belongs to a batch then delegates to the batch request object. Otherwise simply emits response object.

=end pod

use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Message:api<2>;
use Cro::RPC::JSON::MethodResponse:api<2>;
use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Requestish;
use Cro::RPC::JSON::Unmarshal;

also does Cro::RPC::JSON::Message;
also does Cro::RPC::JSON::Requestish;

has JRPCVersion $.jsonrpc; # Version string
has JRPCId $.id;
has Str $.method where *.defined;
has $.params;
has %.data;         # Parsed body of the request
has Str $.invalid;  # Will contain error message if request object was invalid
has $.batch;        # Batch request object to which the request belongs if there is one
has Cro::RPC::JSON::MethodResponse $!jrpc-response;
has Bool:D $.has-params = False;

submethod TWEAK {
    if not %!data<jsonrpc>:exists {
        $!invalid = "Missing required 'jsonrpc' key";
    }
    else {
        for %!data.keys -> $param {
            self."set-$param"( %!data{$param} );
            CATCH {
                when X::Cro::RPC::JSON::InvalidRequest {
                    $!invalid = .msg;
                }
                default {
                    .rethrow
                }
            }
        }
    }
}

#| Sets and validates $.id
method set-id (::?CLASS:D: $id --> Nil) {
    X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid id value: $id of type " ~ $id.WHO) ).throw
        unless $id ~~ JRPCId;
    $!id = $id;
}

#| Sets and validates $.jsonrpc
method set-jsonrpc (::?CLASS:D: $jsonrpc --> Nil) {
    X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid jsonrpc version: $jsonrpc") ).throw
        unless $jsonrpc ~~ JRPCVersion;
    $!jsonrpc = $jsonrpc;
}

#| Sets and validates $.method
method set-method (::?CLASS:D: Str:D $!method --> Nil) {}

#| Sets $.params
method set-params (::?CLASS:D: $!params --> Nil) {
    $!has-params = True;
}

#| Returns true if this request is just a notification (i.e. doesn't have id set)
method is-notification(::?CLASS:D: --> Bool:D) {
    not %!data<id>:exists
}

method jrpc-response( |c --> Cro::RPC::JSON::MethodResponse) {
    unless $!jrpc-response {
        $!jrpc-response = Cro::RPC::JSON::MethodResponse.new: |c, :jrpc-request(self), :$.request;
        # Add this response to related batch response object if part of a batch request
        .jrpc-response.add: $!jrpc-response with $!batch;
        $!jrpc-response.set-error: code => JRPCInvalidRequest, message => $_ with $!invalid;
    }
    $!jrpc-response
}

# Expected to be invoked in a supply context
proto method respond(|) {*}

multi method respond(Exception:D :$exception! --> Nil) {
    self.jrpc-response.set-error($exception);
    self.respond;
}

multi method respond(Mu \data --> Nil) {
    self.jrpc-response.set-result: data;
    self.respond;
}

multi method respond(--> Nil) {
    my $response = self.jrpc-response;
    with $!batch {
        # Only emit a batch response if the related batch request has been fulfilled
        .respond
    }
    else {
        emit $response;
    }
}

=begin pod

=head1 SEE ALSO

L<Cro|https://cro.services>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
