use v6.d;
unit role Cro::RPC::JSON::Message;
=begin pod

=head1 NAME

C<Cro::RPC::JSON::Message> – for classes implementing C<Cro::Message> interface

=head1 DESCRIPTION

The following classes are used by C<Cro::RPC::JSON>:

=item C<Cro::RPC::JSON::Message> -- Interface role
=item C<Cro::RPC::JSON::Request> -- JSON-RPC request class
=item C<Cro::RPC::JSON::Response> -- JSON-RPC response class

=end pod
use Cro::Message;
use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Exception;

also does Cro::Message;

=begin pod

=head1 ATTRIBUTES

=item C<$.jsonrpc> – contains JSON-RPC version
=item C<$.id> – id field if defined in the RPC request

=end pod

has JRPCVersion $.jsonrpc; # Version string
has JRPCId $.id;

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

