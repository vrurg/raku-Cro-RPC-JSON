use v6.d;
unit class Cro::RPC::JSON::Response;

=begin pod

=head1 Cro::RPC::JSON::Response

Defines the following attribute:

=item C<$.json-body> – response body

=end pod

use Cro::Message;
also does Cro::Message;

has $.json-body is rw;

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

