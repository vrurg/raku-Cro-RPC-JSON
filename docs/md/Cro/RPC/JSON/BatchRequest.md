NAME
====

`Cro::RPC::JSON::BatchRequest` - container for requests received as members of a [batch request](https://www.jsonrpc.org/specification#batch)

DESCRIPTION
===========

This class must not be manipulated directly under normal circumstances.

ATTRIBUTES
==========

  * `$.pending` - number of pending requests, i.e. those for which responses were not completed yet (see [`Cro::RPC::JSON::MethodResponse`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.1/docs/md/Cro/RPC/JSON/MethodResponse.md))

  * `Promise:D $.completed` – this promise is kept when all responses are completed

  * [`Cro::RPC::JSON::BatchResponse`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.1/docs/md/Cro/RPC/JSON/BatchResponse.md)`$.response` – batch response object paired to this batch request

METHODS
=======

`requests(--` Seq:D)>
---------------------

All contained requests

`respond()`
-----------

If this batch request is complete, i.e. all of related responses are completed, then it will be emitted.

SEE ALSO
========

[`Cro::RPC::JSON`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.1/docs/md/Cro/RPC/JSON.md), [`Cro::RPC::JSON::Request`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.1/docs/md/Cro/RPC/JSON/Request.md), [`Cro::RPC::JSON::MethodResponse`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.1/docs/md/Cro/RPC/JSON/MethodResponse.md), [`Cro::RPC::JSON::BatchRequest`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.1/docs/md/Cro/RPC/JSON/BatchRequest.md),

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

