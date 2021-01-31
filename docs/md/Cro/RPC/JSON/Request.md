NAME
====

`Cro::RPC::JSON::Request` - prepared JSON-RPC request object

ROLES
=====

Does [`Cro::RPC::JSON::Message`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON/Message.md), [`Cro::RPC::JSON::Requestish`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON/Requestish.md)

ATTRIBUTES
==========

  * `$.jsonrpc` - JSON-RPC version. Currently this attribute always contains *"2.0"*

  * `$.id` - JSON-RPC request id. Undefined if the request is a [notification](https://www.jsonrpc.org/specification#notification).

  * `Str $.method` – request method name

  * `$.params` – request parameters as parsed from JSON-RPC request object `params` key

  * `%.data` – parsed full request JSON object.

  * `Str $.invalid` – undefined for valid requests. Otherwise contains error message explaining the cause.

  * `$.batch` - if request is part of a [batch request](https://www.jsonrpc.org/specification#batch) then this attribute points to corresponding [`Cro::RPC::JSON::BatchRequest`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON/BatchRequest.md) object

METHODS
=======

`set-jsonrpc($jsonrpc)`, `set-id($id)`, `set-method(Str:D $method)`, `set-params($params)`
------------------------------------------------------------------------------------------

Set corresponding attributes.

`set-jsonrpc` and `set-id` throw `X::Cro::RPC::JSON::InvalidRequest` if supplied value is invalid.

`is-notification(--` Bool:D)>
-----------------------------

Returns *True* if request is a [notification](https://www.jsonrpc.org/specification#notification), i.e. when `id` key is not specified.

`jrpc-response(|c)`
-------------------

Returns a [`Cro::RPC::JSON::MethodResponse`](https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.903/docs/md/Cro/RPC/JSON/MethodResponse.md) object paired with the current request. Most of the time this method must be given preference over creating a method response object manually.

`proto respond()`
-----------------

This method is what must be used to respond to a request. It creates a new response object if necessary, completes it, and them calls [`emit`](https://docs.raku.org/routine/emit) with it.

### `multi respond(Any:D $data)`

Takes `$data` and sets it as the result of current request response.

### `multi respond(Exception:D :$exception)`

Takes an exception and produces correct error response from it.

### `multi respond()`

If request belongs to a batch then delegates to the batch request object. Otherwise simply emits response object.

### method set-id

```perl6
method set-id(
    $id
) returns Nil
```

Sets and validates $.id

### method set-jsonrpc

```perl6
method set-jsonrpc(
    $jsonrpc
) returns Nil
```

Sets and validates $.jsonrpc

### method set-method

```perl6
method set-method(
    Str:D $!method
) returns Nil
```

Sets and validates $.method

### method set-params

```perl6
method set-params(
    $!params
) returns Nil
```

Sets $.params

### method is-notification

```perl6
method is-notification() returns Bool
```

Returns true if this request is just a notification (i.e. doesn't have id set)

SEE ALSO
========

[Cro](https://cro.services)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

