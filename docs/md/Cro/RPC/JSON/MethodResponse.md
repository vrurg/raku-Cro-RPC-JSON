NAME
====

`Cro::RPC::JSON::MethodResponse` – container for method response

DESCRIPTION
===========

This class is a mediator between JSON-RPC actor code and the connected client. Normally it's only useful for asynchronous mode of operation (see [`Cro::JSON::RPC`](https://modules.raku.org/dist/Cro::JSON::RPC)). And even then it's better be created using [`Cro::RPC::JSON::Request`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.2/docs/md/Cro/RPC/JSON/Request.md) `response` method.

An instance of this class can be either in incomplete or completed state. The latter means that it has either `$.result` or `$.error` attribute set. Setting both of them is considered a error and `X::Cro::RPC::JSON::ServerError` is thrown then.

Batches
-------

If `Cro::RPC::JSON::MethodResponse` belongs to batch response it reports back to the batch object of [`Cro::RPC::JSON::BatchResponse`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.2/docs/md/Cro/RPC/JSON/BatchResponse.md) when gets completed.

Class `Error`
-------------

`Cro::RPC::JSON::MethodResponse::Error` class is used by this module internally to hold and convert into a JSON object information about errors.

ATTRIBUTES
==========

  * `$.result` - contains the result of calling a JSON-RPC method. Could be any JSONifiable object

  * `$.error` – an instance of `Cro::RPC::JSON::MethodResponse::Error`

  * `$.jrpc-request` - [`Cro::RPC::JSON`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.2/docs/md/Cro/RPC/JSON.md) request object to which this response is generated

Class `Error` Attributes
------------------------

  * `$.code` - one of JSON-RPC error codes.

  * `Str $.message` – a message explaining the error

  * `%.data` - additional data related to the error. Method `set-error` sets this to a hash with two keys: `exception` and `backtrace` of the exception.

METHODS
=======

`filled()`
----------

Returns *True* if response is complete.

`proto set-error(|)`
--------------------

Sets `$.error` either from a hash or from a `X::Cro::RPC::JSON` exception.

`set-result($data)`
-------------------

Sets `$.result` to `$data`.

[`Hash`](https://docs.raku.org/type/Hash)
-----------------------------------------

Returns a hash ready for JSONifying and returning back to the client.

Class `Error` Methods
---------------------

### `set-data(%data)`

Sets `Error`'s `$.data`.

### [`Hash`](https://docs.raku.org/type/Hash)

Returns a hash ready to be used as JSON-RPC object `error` key value.

SEE ALSO
========

[`Cro`](https://cro.services), [`Cro::RPC::JSON`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.2/docs/md/Cro/RPC/JSON.md), [`Cro::RPC::JSON::Request`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.2/docs/md/Cro/RPC/JSON/Request.md), [`Cro::RPC::JSON::BatchResponse`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.2/docs/md/Cro/RPC/JSON/BatchResponse.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

