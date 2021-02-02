use v6.d;
unit class Cro::RPC::JSON::MethodResponse:api<2>;

=begin pod

=head1 NAME

C<Cro::RPC::JSON::MethodResponse> – container for method response

=head1 DESCRIPTION

This class is a mediator between JSON-RPC actor code and the connected client. Normally it's only useful for
asynchronous mode of operation (see L<C<Cro::JSON::RPC>|https://modules.raku.org/dist/Cro::JSON::RPC>). And even then it's better be created using
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.3/docs/md/Cro/RPC/JSON/Request.md>
C<response> method.

An instance of this class can be either in incomplete or completed state. The latter means that it has either
C<$.result> or C<$.error> attribute set. Setting both of them is considered a error and
C<X::Cro::RPC::JSON::ServerError> is thrown then.

=head2 Batches

If C<Cro::RPC::JSON::MethodResponse> belongs to batch response it reports back to the batch object of
L<C<Cro::RPC::JSON::BatchResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.3/docs/md/Cro/RPC/JSON/BatchResponse.md>
when gets completed.

=head2 Class C<Error>

C<Cro::RPC::JSON::MethodResponse::Error> class is used by this module internally to hold and convert into a JSON
object information about errors.

=head1 ATTRIBUTES

=item C<$.result> - contains the result of calling a JSON-RPC method. Could be any JSONifiable object
=item C<$.error> – an instance of C<Cro::RPC::JSON::MethodResponse::Error>
=item C<$.jrpc-request> - L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.3/docs/md/Cro/RPC/JSON.md> request object to which this response is generated

=head2 Class C<Error> Attributes

=item C<$.code> - one of JSON-RPC error codes.
=item C<Str $.message> – a message explaining the error
=item C<%.data> - additional data related to the error. Method C<set-error> sets this to a hash with two keys: C<exception> and C<backtrace> of the exception.

=head1 METHODS

=head2 C<filled()>

Returns I<True> if response is complete.

=head2 C<proto set-error(|)>

Sets C<$.error> either from a hash or from a C<X::Cro::RPC::JSON> exception.

=head2 C<set-result($data)>

Sets C<$.result> to C<$data>.

=head2 L<C<Hash>|https://docs.raku.org/type/Hash>

Returns a hash ready for JSONifying and returning back to the client.

=head2 Class C<Error> Methods

=head3 C<set-data(%data)>

Sets C<Error>'s C<$.data>.

=head3 L<C<Hash>|https://docs.raku.org/type/Hash>

Returns a hash ready to be used as JSON-RPC object C<error> key value.

=end pod

use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Requestish;

also does Cro::RPC::JSON::Message;

our enum ResponseState <RCUnset RCResult RCError>;

our class Error {
    has JRPCErrCode $.code is required;
    has Str $.message is required;
    has Hash $.data;

    method COERCE(%p --> ::?CLASS:D) {
        self.new: |%p
    }

    method Hash ( --> Hash ) {
        %( :$!code, :$!message, |( $!data.defined ?? :$!data !! (  ) ) )
    }

    method set-data(%data) {
        $!data = %data;
    }
}

has Mu $.result is default(Any) is built(False);
has Error(Hash) $.error is built(False);
has ResponseState:D $!state = RCUnset;
has Cro::RPC::JSON::Message:D $.jrpc-request is required;

submethod TWEAK(*%c) {
    if %c<error>:exists {
        self.set-error: %c<error>;
    }
    if %c<result>:exists {
        self.set-result: %c<result>;
    }
}

method filled {
    $!state == RCUnset
}

method !set-yet {
    unless $!state == RCUnset {
        X::Cro::RPC::JSON::ServerError.new(
            :msg( "Alteration of a response result attempted for method '"
                  ~ $!jrpc-request.method
                 ~ "', id=" ~ $!jrpc-request.id),
            :code(JRPCErrGeneral)).throw;
    }
}

proto method set-error(::?CLASS:D: | --> Error:D) {*}
multi method set-error (*%err) {
    self!set-yet;
#    note "!!! set error from: ", %err;
    $!error = Error.new(|%err);
    $!state = RCError;
    with $!jrpc-request.batch { .complete($!jrpc-request) }
    $!error
}

multi method set-error(X::Cro::RPC::JSON:D $exception) {
    self.set-error( code => $exception.jrpc-code, message => $exception.msg );
    $!error.set-data($_) with $exception.data;
    $!error
}

multi method set-error(Exception:D $exception) {
    self.set-error(
        code => JRPCInternalError,
        message => $exception.message,
        data => %( exception => $exception.^name,
                   backtrace => ~$exception.backtrace, ));
}

multi method set-error(Error:D $error) {
    self!set-yet;
    $!state = RCError;
    $!error = $error;
}

method set-result(::?CLASS:D: Mu \data --> Nil) {
    self!set-yet;
    # If data is undefined then $!result will remain set to Any which translates into JSON's null
    $!result = $_ with data;
    $!state = RCResult;
    # If part of a batch request then update its status
    with $!jrpc-request.batch { .complete($!jrpc-request) }
}

method Hash ( --> Hash ) {
    my $req = $.jrpc-request; # The initial request
    my $id = $req.id;
    %(
        :jsonrpc($req.jsonrpc // JRPC-DEFAULT-VERSION),
        |( $id.defined ?? :$id !! Empty ),
        $!state == RCResult
            ?? :$!result
            !! :error(
                $!state == RCError
                    ?? $!error.Hash
                    !! {
                            code => JRPCInternalError,
                            message => "method response contains neither result not error fields",
                            data => %(
                                classification => "internal",
                                :$id,
                                method => $req.method,
                            ),
                        }
                ),
    )
}

=begin pod

=head1 SEE ALSO

L<C<Cro>|https://cro.services>,
L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.3/docs/md/Cro/RPC/JSON.md>,
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.3/docs/md/Cro/RPC/JSON/Request.md>,
L<C<Cro::RPC::JSON::BatchResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.3/docs/md/Cro/RPC/JSON/BatchResponse.md>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
