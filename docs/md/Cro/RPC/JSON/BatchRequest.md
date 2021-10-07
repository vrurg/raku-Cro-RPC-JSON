NAME
====

`Cro::RPC::JSON::BatchRequest` - container for requests received as members of a [batch request](https://www.jsonrpc.org/specification#batch)

DESCRIPTION
===========

This class must not be manipulated directly under normal circumstances.

ATTRIBUTES
==========

  * `$.pending` - number of pending requests, i.e. those for which responses were not completed yet (see [`Cro::RPC::JSON::MethodResponse`](MethodResponse.md))

  * `Promise:D $.completed` – this promise is kept when all responses are completed

  * [`Cro::RPC::JSON::BatchResponse`](BatchResponse.md)`$.jrpc-response` – batch response object paired to this batch request

METHODS
=======

`jrpc-requests(--` Seq:D)>
--------------------------

All contained requests

`respond()`
-----------

If this batch request is complete, i.e. all of related responses are completed, then it will be emitted.

SEE ALSO
========

[`Cro::RPC::JSON`](../JSON.md), [`Cro::RPC::JSON::Request`](Request.md), [`Cro::RPC::JSON::MethodResponse`](MethodResponse.md), [`Cro::RPC::JSON::BatchRequest`](BatchRequest.md),

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

