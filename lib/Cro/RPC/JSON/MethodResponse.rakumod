use v6.d;
unit class Cro::RPC::JSON::MethodResponse;

use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Message;

also does Cro::RPC::JSON::Message;

our class Error {
    has JRPCErrCode $.code is required;
    has Str $.message is required;
    has Hash $.data;

    method Hash ( --> Hash ) {
        %( :$!code, :$!message, |( $!data.defined ?? :$!data !! (  ) ) )
    }

    method set-data(%data) {
        $!data = %data;
    }
}

has $.result is rw;
has Error $.error is rw;
has Cro::RPC::JSON::Message $.request is rw;

submethod TWEAK {
    $!jsonrpc //= "2.0";
}

method set-error ( *%err ) {
    $.error = Error.new(|%err);
}

method Hash ( --> Hash ) {
    %(
        :$.jsonrpc,
        |( $.id.defined ?? :$.id !! Empty ),
        $.result.defined
            ?? :$.result
            !! :error(
                $.error.defined
                    ?? $.error.Hash
                    !! {
                            code => JRPCInternalError,
                            message => "method response contains neither result not error fields",
                            data => %(
                                classification => "internal",
                                id => $.request.id,
                                method => $.request.method,
                            ),
                        }
                ),
    )
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

