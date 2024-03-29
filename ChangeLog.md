VERSIONS
========

v0.1.5
------

  * FIX: availability of `json-rpc`, `jrpc-protocol`, `jrpc-async`, and Cro's `request` routines.

v0.1.4
------

  * Implemented marshalling/unmarshalling of arguments and return values.

  * FIX: a bug preventing methods from returning [`Nil`](https://docs.raku.org/type/Nil) or non-[`Any`](https://docs.raku.org/type/Any) typeobjects.

v0.1.2
------

  * Due to an overlooked naming conflict with Cro attributes and methods named `request` and `response` had to be renamed. To maintain consistency with exported subs `jrpc-request` and `jrpc-response`, the attributes have been renamed after them to `$.jrpc-request` and `$.jrpc-response`. Same has been done to the plural forms in batch request classes. Unfortunately, the change is incompatible with v0.1.1. For this reason it was decided to pull out both v0.1.0 and v0.1.1 from CPAN.

  * Tighten bonds with [Cro's](https://cro.services) [`request`](https://cro.services/docs/reference/cro-http-request). Now `request` term exported by [`Cro::HTTP::Router`](https://cro.services/docs/reference/cro-http-router) will work where applicable.

  * Implemented JSON-RPC method call authorization.

  * Switching to [`zef`](https://github.com/tony-o/raku-fez) ecosystem

v0.1.1
------

Bugfixes

v0.1.0
------

The module has undergone major rewrite in this version. Most notable changes are:

  * Introduced WebSockets support, including pushing notifications back to clients

  * Added complete support for parameterized roles

  * Added different mode of operations

  * Changes in API this module provides require it to get `:api<2>` adverb.

