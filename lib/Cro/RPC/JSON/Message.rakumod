use v6.d;
unit role Cro::RPC::JSON::Message:api<2>;
=begin pod

=head1 NAME

C<Cro::RPC::JSON::Message> – role defining standard C<Cro::RPC::JSON> message object

=head1 ATTRIBUTES

=item C<$.json-body> – any JSONifiable object

=end pod

use Cro::Message;
use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Exception;

also does Cro::Message;

has $.json-body is rw;

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|../JSON.md>,
L<C<Cro::RPC::JSON::Request>|Request.md>,
L<C<Cro::RPC::JSON::MethodResponse>|MethodResponse.md>,
L<C<Cro::RPC::JSON::BatchRequest>|BatchRequest.md>,
L<C<Cro::RPC::JSON::Notification>|Notification.md>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
