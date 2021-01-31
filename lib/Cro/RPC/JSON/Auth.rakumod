use v6.d;
unit role Cro::RPC::JSON::Auth;

=begin pod
=head1 NAME

C<Cro::RPC::JSON::Auth> - basic role for implementing JSON-RPC authorization

=head1 METHODS

=head2 C<json-rpc-authorize($auth --> Bool)>

This method is required to be implemented by consuming class. It must take the supplied C<$auth> object and return
a L<C<Bool>|https://docs.raku.org/type/Bool> which is I<True> only when authorization is granted.

=end pod

# Require a HTTP request auth object to provide method authorization means.
method json-rpc-authorize($ --> Bool) {...};

=begin pod

=head1 SEE ALSO

L<C<Cro::RPC::JSON>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON.md>,
L<Cro documentation|https://cro.services/docs/http-auth-and-sessions>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
