use v6.d;
unit class Cro::RPC::JSON::Request;

=begin pod

=head1 Cro::RPC::JSON::Request

Defines following attributes:

=item C<$.method> – request method name
=item C<$.params> – request parameters
=item C<%.data> – parsed raw request body.
=item C<$.invalid> – Undefined if request is valid; otherwise contains error message explaining the cause.

C<$.invalid> would be set by one of C<set-*> methods below.

=end pod

use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Utils;

also does Cro::RPC::JSON::Message;

has JRPCMethod $.method;
has $.params;
has %.data;         # Parsed body of the request
has $.invalid;      # Will contain error message if request object was invalid

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

#| Sets and validates $.jsonrpc
method set-jsonrpc ( $jsonrpc ) {
    X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid jsonrpc version: $jsonrpc") ).throw
    unless $jsonrpc ~~ JRPCVersion;
    $!jsonrpc = $jsonrpc;
}

#| Sets and validates $.id
method set-id ($id) {
    X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid id value: $id of type " ~ $id.WHO) ).throw
    unless $id ~~ JRPCId;
    $!id = $id;
}

#| Sets and validates $.method
method set-method ( $method ) {
    X::Cro::RPC::JSON::InvalidRequest.new( :msg("Invalid method name: $method") ).throw
    unless $method ~~ JRPCMethod;
    $!method = $method;
}

#| Sets $.params
method set-params ( $!params ) {}

#| Returns true if this request is just a notification (i.e. doesn't have id set)
method is-notification {
    not %!data<id>:exists
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

