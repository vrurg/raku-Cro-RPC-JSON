use v6.d;
unit class Cro::RPC::JSON::RequestParser;
use Cro::RPC::JSON::RequestParser::BodyStr;

=begin pod

=head1 NAME

C<Cro::RPC::JSON::RequestParser> - base class for request parsers

=head1 ROLES

Does L<C<Cro::RPC::JSON::RequestParser::BodyStr>|RequestParser/BodyStr.md>

=end pod

also does Cro::RPC::JSON::RequestParser::BodyStr;

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|../JSON.md>,
L<Cro|https://cro.services>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
