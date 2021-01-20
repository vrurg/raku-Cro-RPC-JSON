use v6.d;
unit class Cro::RPC::JSON::Notification:api<2>;

=begin pod
=head1 NAME

C<Cro::RPC::JSON::Notification> - container for notifications to be pushed to the client

=name1 DESCRIPTION

Only makes sense with WebSocket transport.

=end pod

use Cro::RPC::JSON::Message;

also does Cro::RPC::JSON::Message;

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
