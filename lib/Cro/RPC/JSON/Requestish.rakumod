use v6.d;
unit role Cro::RPC::JSON::Requestish;
use Cro::HTTP::Request;

=begin pod

=head1 NAME

C<Cro::RPC::JSON::Requestish> - role for classes bound to L<C<Cro::HTTP::Request>|https://cro.services/docs/reference/cro-http-request>

=head1 ATTRIBUTE

=item C<Cro::HTTP::Request:D $.request> – Cro's HTTP request object.

=end pod

has Cro::HTTP::Request:D $.request is required;

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.4/docs/md/Cro/RPC/JSON.md>,
L<Cro|https://cro.services>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
