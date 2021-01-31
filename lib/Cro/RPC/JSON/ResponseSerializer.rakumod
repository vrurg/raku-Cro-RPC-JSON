use v6.d;
unit class Cro::RPC::JSON::ResponseSerializer;

=begin pod

=head1 NAME

C<Cro::RPC::JSON::ResponseSerializer> - base class for response serializers

=head1 ROLES

Does L<C<Cro::RPC::JSON::Requestish>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON/Requestish.md>

=end pod

use Cro::RPC::JSON::Requestish;

also does Cro::RPC::JSON::Requestish;

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON.md>,
L<Cro|https://cro.services>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
