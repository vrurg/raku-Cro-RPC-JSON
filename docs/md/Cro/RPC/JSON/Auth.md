NAME
====

`Cro::RPC::JSON::Auth` - basic role for implementing JSON-RPC authorization

METHODS
=======

`json-rpc-authorize($auth --` Bool)>
------------------------------------

This method is required to be implemented by consuming class. It must take the supplied `$auth` object and return a [`Bool`](https://docs.raku.org/type/Bool) which is *True* only when authorization is granted.

SEE ALSO
========

[`Cro::RPC::JSON`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.904/docs/md/Cro/RPC/JSON.md), [Cro documentation](https://cro.services/docs/http-auth-and-sessions)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

