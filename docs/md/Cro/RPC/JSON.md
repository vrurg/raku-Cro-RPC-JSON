NAME
====

`Cro::RPC::JSON` - server side JSON-RPC 2.0 in minutes

SYNOPSIS
========

    use Cro::HTTP::Server;
    use Cro::HTTP::Router;
    use Cro::RPC::JSON:api<2>;

    class JRPC-Actor is export {
        method foo ( Int :$a, Str :$b ) is json-rpc("FOO") {
            return "$b and $a";
        }

        proto method bar (|) is json-rpc { * }

        multi method bar ( Str :$a! ) { "single named Str param" }
        multi method bar ( Int $i, Num $n, Str $s ) { "Int, Num, Str positionals" }
        multi method bar ( *%options ) { [ "slurpy hash:", %options ] }

        method non-json (|) { "I won't be called!" }
    }

    sub routes is export {
        my $actor = JRPC-Actor.new;
        route {
            # Use an object implementation of API
            post -> "api" {
                json-rpc $actor;
            }
            # Use a code-based implementation of API
            post -> "api2" {
                json-rpc -> Cro::RPC::JSON::Request $jrpc-req {
                    { to-user => "a string", num => pi }
                }
            }
        }
    }

DESCRIPTION
===========

The initial and primary purpose of this module is to provide a fast path to make your class-based API implementation available to serve [JSON-RPC 2.0](https://www.jsonrpc.org/specification) requests over both HTTP/POST and WebSocket protocols with as little pain as possible. In many cases it is feasible to use the same method to serve both your Raku code and JSON-RPC calls without any special case code paths in the method implementation.

Alongside with supporting class-based API implementation the module also supports code-based scenarios where JSON-RPC requests are handled by a single user-provided code object like a pointy block or a `sub`. This case has two modes of operation: synchronous and asynchronous. These will be discussed later.

Modes Of Operation
------------------

`Cro::RPC::JSON` supports the following modes of operation in mutually exclusive pairs:

  * code or object

  * HTTP or WebSocket

  * synchronous or asynchronous

### Code vs. Object

The [SYNOPSIS](#SYNOPSIS) provides examples for both of the modes. For any relatively complex API object mode would be preferred over code for its higher abstraction level and, correspondingly, for better maintainabilty.

Declaring a class for serving a JSON-RPC requests is as simple as adding `is json-rpc` trait to some of its methods. If we consider `JRPC-Actor` class from [SYNOPSIS](#SYNOPSIS) then calling its method `bar` from a remote client would be done with the following JSON structure:

    {
        jsonrpc: "2.0",
        id: 314,
        method: "bar",
        params: { a: "string" }
    }

Which will result in invoking the first `bar` multi-candidate with named parameter `:a<string>`. But if we pass an array together with `params` key: `[42, 3.1415926, "anything"]` – then the second multi-candidate will be called with three positional arguments. This is the basic rule of translation used by `Cro::RPC::JSON`: a top-level JSON object is translated into named parameters; a top-level array represents positional parameters. See more information about handling of method arguments and return values in the [Method Call Convention](#Method Call Convention) section below.

More information about exporting methods for JSON-RPC is provided in `json-rpc` trait section below.

Handling a JSON-RPC request by a code object is considered more low-level approach. Particular format of the code is determined by wether it operates in synchronous or asynchronous mode (see below), general principle is: the code is provided with a [`Cro::RPC::JSON::Request`](JSON/Request.md) object and must produce JSONifiable return value which is then returned to the client. The [SYNOPSIS](#SYNOPSIS) provides the most simple case of a synchronous code object. Any call to JSON-RPC to any method in the example will return:

    {
        jsonrpc: "2.0",
        id: <user-request-id>,
        result: { "to-user": "a string", num: 3.141592653589793 }
    }

### HTTP And WebSocket

The difference between these two modes is in the nature of the protocols: where HTTP supports single request/response, WebSocket supports continuous flow of requests/responses and bidirectional communication between client and server. Because handling of an HTTP request is rather easy to understand we're not going to focus much on it. Instead, let's focus in WebSocket specifics of implemeting JSON-RPC by `Cro::RPC::JSON`.

First of all, it has to be mentioned that there is no single specification of how JSON-RPC over WebSocket is to be implemented. `Cro::RPC::JSON` targetting at supporting [rpc-websockets](https://github.com/elpheria/rpc-websockets) implementation for JavaScript.

To handle JSON-RPC request/response protocol a WebSocket stream is considered a bidirectional sequence of JSON objects or arrays of JSON-RPC batch requests/responses. Any server-side notification pushed toward the client must be a JSON object and must not contain `jsonrpc` key.

From the server implementation side of things the above said means that for object mode of operation there is nothing to be changed in method implementations. Everything is handled automatically and makes no difference with HTTP requests. For code objects in synchronous mode there is no change either. But for asynchronous ones it is recommended to use `jrpc-notify` sub to simplify producing of a valid JSON return. The exact meaning of this statement will be clear later.

To get your server support WebSocket transport all is needed is two changes in router code: `get` to be used in place of `post`; and `:web-socket` named argument to be added to call to `json-rpc`:

    route {
        my $actor = JRPC-Actor.new;
        get -> "api" {
            json-rpc :web-socket, $actor;
        }
    }

Same applies to a synchronous code mode:

    route {
        get -> "api2" {
            json-rpc :web-socket, -> Cro::RPC::JSON::Request $jrpc-req {
                { to-user => "a string", num => pi }
            }
        }
    }

The asynchronous mode wil be considered in the corresponding section later.

It is still possible though for both object and synchronous code mode cases to provide async notifications. See `:async` in sections dedicated to `json-rpc` routine and `json-rpc` trait.

### Synchronous And Asynchronous

Hopefully, by this moment it is clear that in synchronous mode of operation user code receives a request in either raw, as [`Cro::RPC::JSON::Request`](JSON/Request.md) instance, or in a "prepared" form as method arguments. One way or another, a JSONifiable response is produced and that's the end of the cycle for server-side user code.

In asynchronous mode things are pretty much different. First of all, it's not supported for objects; though they still can provide asynchronous notifications using `json-rpc` trait `:async` argument. Second, a code in asynchronous mode receives a [`Supply`](https://docs.raku.org/type/Supply) of incoming requests as an argument and must return a supply emitting [`Cro::RPC::JSON::MethodResponse`](JSON/MethodResponse.md) objects. This is the lowest mode of operation as in this case the code is plugged almost directly into a [`Cro`](https://cro.services) pipeline. See `respond` helper method in [`Cro::RPC::JSON::Request`](JSON/Request.md) which allows to reduce the number of low-level operations needed to emit a resut.

Here is an example of the most simplisic asynchronous code implementation. Note the strict typing used with `$in` parameter. This is how we tell `Cro::RPC::JSON` about our intention to operate asynchronously:

    route {
        get -> 'api' {
            json-rpc :web-socket, -> Supply:D $in {
                supply {
                    whenever $in -> $req {
                        $req.respond: { to-user => "a string", num => pi }
                    }
                }
            }
        }
    }

**Note** that the same asynchronous code can be used for processing an HTTP request too. In this case `:web-socket` argument is not used, `get` turns into `post`, yet otherwise the sample doesn't change. But what remains the same is that `$in` would emit exactly one request object corresponding to the single HTTP `POST`. So, the only case when this approach makes sense if when the same code object is re-used for both WebSocket and HTTP modes.

The above example can be extended to provide additional functionality when operating on a WebSocket:

    route {
        get -> 'api' {
            json-rpc :web-socket, -> $in, $close {
                supply {
                    whenever $in -> $req {
                        $req.respond: { to-user => "a string", num => pi }
                    }
                    whenever $close -> $req {
                        $close-code = (await $req.body).read-uint16(0);
                        done;
                    }
                    whenever Supply.interval(1) {
                        jrpc-notify %(
                            :notification<tick-tock>,
                            :params( { :time(now) } )
                        )
                    }
                }
            }
        }
    }

First of all, the absense of `Supply` in front of `$in` is not an error here. Another way to request asynchronous mode of operation is to use declare two parameters. In this case the second one is expected to be a close [`Promise`](https://docs.raku.org/type/Promise) as provided by [`Cro::HTTP::Router::WebSocket`](https://cro.services/docs/reference/cro-http-router-websocket#Receiving_close_messages).

The last `whenever` block apparently produces a notification every second which is then pushed back to the client.

`Cro::RPC::JSON` also provides a hybrid mode of operation where it is possible to provide asynchronous events alongside with a synchronous code. See `:async` argument of `json-rpc` trait and `json-rpc` sub.

MODULE HELPERS
==============

`json-rpc`
----------

`json-rpc` is a multi-dispatch `sub` which must be used inside `Cro` `get` or `post` blocks, depending on what transport protocol, HTTP or WebSockets, is to be served. In its most simplistic form `json-rpc` takes a single code object:

    json-rpc -> $req { ... }

Or:

    json-rpc -> Supply $in { ... }

As it was noted above, the type of argument determines wether the code block is to operate in synchronous or asynchronous mode.

Adding a named argument `:web-socket` would tell `json-rpc` to wrap around `Cro`'s `web-socket` subroutine. Same rules about synchronous/asynchronous mode of operation apply:

    json-rpc :web-socket, -> $req { ... }
    json-rpc :web-socket, -> Supply $in { ... }
    json-rpc :web-socket, -> $in, $close { ... }

    I<C<:web-socket> is also available as C<:ws> or C<:websocket> aliases.>

If the first positional argument of `json-rpc` is anything but a code then it is expected to be an object providing methods for JSON-RPC calls. I.e. those marked with `is json-rpc` trait:

    class JRPC-Actor {
        method authorise(Str:D $name, Str:D $password) is json-rpc { ... }
    }
    route {
        my $actor = JRPC-Actor.new;
        get -> "api" {
            json-rpc $actor;
        }
    }

The `$actor` object can also be accompanied with `:web-socket` (`:ws`, `:websocket`) argument.

### `:async`

When a synchronous code is used with `:web-socket` argument it is still possible to emit asynchronous notifications. This is done by passing `:async` named argument to the subroutine which is expected to be a code block which can accept a single argument – WebSocket `$close` [`Promise`](https://docs.raku.org/type/Promise); and which will return a [`Supply`](https://docs.raku.org/type/Supply). The supply is expected to emit JSONifiable notifications to be pushed back to the client code. For example, this is a code from *060-websocket.rakutest* test file:

    json-rpc :ws, {
        {:foo<sync-bar>}
    }, async => -> $close {
        supply {
            my $count = 0;
            my $tap;
            whenever $close { # WebSocket close promise
                $close-code = (await .body).read-uint16(0);
                $tap.close;
            }
            $tap = do whenever Supply.interval(.1) {
                ++$count;
                emit {
                    :notification("tick-tock"),
                    :params({:$count})
                }
            }
        }
    }

This little trick allows us to use same synchronous code for serving both HTTP and WebSocket protocols while still allow for asynchronous operations with WebSockets.

This mode of operation is called *hybrid* because it combines both synchronous and asynchronous ones.

**Note** that contrary to the asynchronous code above we don't use `jrpc-notify` to emit a notification. This is because in the case of asynchronous code there is no way for `Cro::RPC::JSON` core to tell the difference between a reponse to a JSON-RPC method call or a notification if they both are hashes, for example, as both are coming from the same supply. That's why one have to wrap them in either [`Cro::RPC::JSON::MethodResponse`](JSON/MethodResponse.md) or [`Cro::RPC::JSON::Notification`](JSON/Notification.md) containers. Besides, when it comes to responding to a method call in the asynchronous model the order of responses is not determined. That's why use of `$req.respond` ensures that the data emitted has the right `id` field set in JSON-RPC response object.

`jrpc-request`
--------------

Returns currently being processed [`Cro::RPC::JSON::Request`](JSON/Request.md) object where applicable and the object is not directly available. Mostly useful for methods of actor class.

`jrpc-response`
---------------

Returns currently being processed [`Cro::RPC::JSON::MethodResponse`](JSON/MethodResponse.md) object where applicable and the object is not directly available. Mostly useful for methods of actor class. Also available as `jrpc-request.jrpc-response`.

`jrpc-protocol`
---------------

A string representing the current transport protocol. Only one of two values is available: *HTTP* or *WebSocket*.

`jrpc-async`
------------

A [`Bool`](https://docs.raku.org/type/Bool) which is *True* if the code object passed to `json-rpc` subroutine is detected as asynchronous. For object mode of operation it is always *False* for JSON-RPC methods and always *True* for `:async` and `:wsclose` methods (see `json-rpc` trait section below).

**Note** that both `jrpc-protocol` and `jrpc-async` are only available outside of `supply` block of asynchronous code objects. Similarly, `jrpc-request` and `jrpc-response` are not available in asynchronous mode.

`jrpc-notify`
-------------

This subroutine is a conivenience means to reduce the boilerplate of asynchronous code emitting notifications. All it does is wraps it's argument into a [`Cro::RPC::JSON::Notification`](JSON/Notification.md) instance and calls `emit` with the object.

CREATING AN ACTOR CLASS
=======================

Writing an actor class is the most advanced and the most simple way of implementing a complex API. As it was already stated before, the biggest *pro* of this approach is abstracting API implementation from the means of accessing it. In other words, normally it is sufficient to have:

    use Cro::RPC::JSON:api<2>;
    class JRPC-Actor {
        method add(Int:D $a, Int:D $b) is json-rpc { $a + $b }
    }

The method is then available for both [Raku](https://raku.org) on the server side as:

    my $sub = $actor.add(13, 42);

And for the client code in JavaScript running in a browser:

    let WebSocket = require('rpc-websockets').Client;
    let ws = new WebSocket('ws://localhost:3000');
    let sum = await ws.call("add", [13, 42]);

Similar JavaScript code can be imagined for any alternative client-side JSON-RPC implementation.

Apparently, all one needs is to use `is json-rpc` trait to mark a method as a JSON-RPC compatible.

**Note** that while we mostly talk about an *actor class* the trait can also be applied to methods in roles. Consuming such role turns a class into a JSON-RPC actor implementation automatically. Inheriting from an actor class also preserves access to the JSON-RPC methods unless they're redefined in a child class without `is json-rpc` trait. *t/005-trait.rakutest* test can be very helpful in providing examples of how things work with Raku OO model.

Method Call Convention
----------------------

Methods exported for JSON-RPC are invoked with parameters received from a JSON-RPC request, de-serialized, and flattened. In other words it can be illustrated with:

    $actor.jrpc-method( |from-json($json-params) );

Apparently, this turns any JSON array into positional parameters; and any JSON object into named parameters. Due to the limitations of JSON format, there is no way to pass both named and positionals at the same time.

The only exception from this rule are methods with a single parameter typed with [`Cro::RPC::JSON::Request`](JSON/Request.md). This way a method indicates that it wants to do in-depth analysis of the incoming requests and expects a raw request object.

For developer conivenience the module provides automated serialization of method's return values and de-serialization of arguments. With this feature it's event more easy to write methods universal for both Raku and RPC side of things; and even less boilerplate for any kind of thunk methods.

The most simple case is serialization of return values. It's done in a very straightforward way: a method return is passed to `JSON::Marshal::marshal` sub. The outcome is then sent back to the RPC client.

Somewhat more complicate approach is used for method arguments recived via `params` key of JSON-RPC request. First of all, the module checks if `params` is an array. And if it is then it is considered as a list of positional arguments. This is an unbendable rule.

If `params` is a JSON object and the callee method doesn't have a positional parameter then `params` is considered a set of named arguments. Otherwise it's considered to be the only positional argument of the method.

Before submitting the arguments to the method `Cro::RPC::JSON` first tries to de-serialize them based on method's signature and parameter typing. The algorithm used is basically identical for both positionals and nameds: the module iterates over arguments, matches them to method parameters, and then `JSON::Unmarshal::unmarshal()` with parameter's type. For example:

    class Product {
        has Int $.SKU;
        has Str $.name;
    }
    method to-inventory(Product:D $item, Int:D $count) is json-rpc { ... }

When `to-inventory` is invoked via this JSON-RPC request:

    {
        id: 1,
        jsonrpc: "2.0",
        method: "to-inventory",
        params: [
            { SKU: 42, name: "Traveller's Towel" },
            13
        ]
    }

the first object in `params` array will be de-serialized into a `Product` instance. That's it, we now have method which can be transparently used by both Raky and RPC callers!

If the method is changed to use named parameters:

    method to-inventory(Product:D :$item, Int:D :$count) is json-rpc {...}

Then `params` must be turned into a JSON object like this:

    {
        item: { SKU: 42, name: "Traveller's Towel" },
        count: 13
    }

And the outcome will be no different of the positional variant.

Aliasing of named parameters is supported. With this signature:

    method to-inventory(Product:D :product(:$item), Int:D :$count) is json-rpc {...}

We can use the following `params` JSON object:

    {
        product: { SKU: 42, name: "Traveller's Towel" },
        count: 13
    }

`Any` type is special cased here. Parameters of `Any` type receive corresponding arguments from the request as-is, no unmarshaling attempted beyond de-stringification of a JSON entity:

    method foo($x, $y) is json-rpc {...}

    params: [true, { a: 1 }]

`$x` here will be set to *True*, `$y` – to hash `{ a =` 1 }>.

It is also possible to pass a single positional array argument with `params: [[1, 2, 3]]`.

The unmarshalling will also work correctly for parameterized arrays and hashes. So, if we need to add several objects of the same kind we can do it like this:

    method to-catalog(Product:D @items) is json-rpc {...}

And it will work with:

    params: [
        { SKU: 42, name: "Traveller's Towel" },
        { SKU: 13, name: "A Happy Amulet" },
        { SKU: 256, name: "Product 100000000" }
    ]

`to-catalog` will receive an array of `Product` instances.

Slurpy parameters are supported as well as captures. The module doesn't attempt unmarshalling of arguments to be consumed by slurpies or captures because there is no way for us to know their types.

The situation is pretty much identical for multi-dispatch methods where to know the eventual candidate to be invoked we nede to know argument types; but we can't know them because we don't know the candidate! For this reason de-serialization is only done based on `proto` method signature:

    proto method categorize-product(Product:D, |) is json-rpc {*}
    multi method categorize-product(Product:D $item, Str:D $category-name) {...}
    multi method categorize-product(Product:D $item, Int:D $category-id) {...}

    params: [{ SKU: 42, name: "Traveller's Towel" }, "fictional"]
    params: [{ SKU: 13, name: "A Happy Amulet" }, 12]

Apparently, each of the `params` will dispatch as expected.

Authorizing Method Calls
------------------------

`Cro::RPC::JSON` provide means to implement session-based authorization of a method call. It is based on the following two key components:

  * Session object, as [documented in a Cro paper](https://cro.services/docs/http-auth-and-sessions), available via `request.auth`. The object must consume [`Cro::RPC::JSON::Auth`](JSON/Auth.md) role and implement `json-rpc-authorize` method

  * Authorization object provided with `:auth` modifier of either `json-rpc` or `json-rpc-actor` traits (see below)

The Cro's session object used to authenticate/authorize a HTTP session or a WebSocket connection is expected to provide means of authorizing JSON-RPC method calls too. For this purpose it is expected to consume [`Cro::RPC::JSON::Auth`](JSON/Auth.md) role and implement `json-rpc-authorize` method. Generally speaking, the method is expected to either authorize or prohit an RPC method call based on the available session data. For example, here is an implementation of the session object from a test suite:

    my class SessionMock does Cro::RPC::JSON::Auth does Cro::HTTP::Auth {
        method json-rpc-authorize($meth-auth) {
            return False if $meth-auth eq 'admin';
            return True if $meth-auth eq 'user' | 'group';
            die "Can't authorize with ", $meth-auth, ": no such privilege";
        }
    }

This one is really simplistic. It prohibits any activity if it requires *admin* privileges; and only allows anything requiring *user* or *group*. Apparently, the real life requires something more sophisticated, depending on the authorization model of your application.

It is worth mentioning that the auth object associated with a method can be virtually of any type given it's a definite. For example, it can be a [`Junction`](https://docs.raku.org/type/Junction):

    method self-destroy() is json-rpc(:auth('root' | 'admin')) {...}

Because defining the same auth object for every JSON-RPC method could be really boresome, it is possible to define the default one by associating it with actor class:

    class Foo is json-rpc-actor(:auth<user>) {
        ...
    }

In this case every JSON-RPC method is considered having *user* auth associated with them unless otherwise specified manually per method declaration.

The authorization takes place whenever a definite auth object can be associated with a method. I.e. it could be an object defined for the method itself; or a default one can be found. Note also that there is no way to bypass authorization in the latter case.

There are some specifics of the authorization process to be considered when class inheritance is involved:

  * If a class inherits from one or more actor classes but is not formally declared as a JSON-RPC actor itself then the first defined auth object found on a parent actor class is used.

  * The found default auth object overrides any other default specified for classes/roles located further in MRO list. I.e. if classes `Foo` and `Bar` appear in MRO in the order of mentioning; and if `Foo` uses *manager* as the default auth, whereas `Bar` default is *admin*; then any JSON-RPC method from `Bar` with no explicit auth attached will be considered as having it set to *manager*.

`is json-rpc` Method Trait
--------------------------

In its most simplistic form the trait simply marks a method and exports it for JSON-RPC calls under the same name it is declared in the actor class. But sometimes we need to export it under a different name than the one available for Raku code. In this case we can pass the desired name as trait's first positional argument:

    method add(Int:D $a, Int:D $b) is json-rpc("sum") { $a + $b }

Now we would have to replace *"add"* string in the last JavaScript example with *"sum"*.

The trait also accepts a number of named arguments which are going to be discussed next. They're called *modifiers* as they modify the way the methods are treated by `Cro::RPC::JSON` core. It is important to remember that some modifiers make a method unavailable for JSON-RPC calls:

    method helper() is json-rpc(:async) { ... }                 # Not available for JSON-RPC

Methods marked wit these modifiers become *ad-hoc* methods; the modifiers are correspondingly called *ad-hoc* too. One of the features making ad-hoc methods different from JSON-RPC exports is that they're not overridable in child classes. In other words, if class `Foo` inherits from `Bar` and both define a `:async` ad-hoc named `event-emitter` then both methods will be incorporated into JSON-RPC pipeline. This feature makes `submethod`s ideal candidates for ad-hoc implementation.

Though it's pretty much a bad idea, but if an ad-hoc method is given a name then it becomes a JSON-RPC export too. If for some reason a developer considers this approach then it is better be done by means of a multi-dispatch via applying the trait to method's `proto`:

    proto method universal(|) is json-rpc("foo", :async) {...}
    multi method universal(Promise:D $close) { ... }  # Take care of :async
    multi method universal(|c) {...} # Take care of API calls.

It is also worth mentioning that applying the trait to a `multi` candidate is equivalent to applying it to its `proto`. While being generally useless withing a class, it allows us to turn a method of parent class into a JSON-RPC accessible one:

    class Foo {
        has $.value;
        proto method add(|) {*}
        multi method add(::?CLASS:D $b) { $!value += $b.value }
        ...
    }
    class Bar is Foo {
        multi method add($a, $b) is json-rpc { $!value = $a.value + $b.value }
    }

So, it is now possible to use the single-argument version of `add` method by a remote client too.

### Ad-Hoc Modifier `:async`

`:async` modifier must be used with methods providing asynchronous events for WebSocket transport. Rules similar to [`json-rpc`](#json-rpc) `:async` named argument apply:

  * the method must return a supply emitting either [`Cro::RPC::JSON::Notification`](JSON/Notification.md) instances or JSONifiable objects

  * the method may have a single parameter – the WebSocket `$close` [`Promise`](https://docs.raku.org/type/Promise)

    method event-emitter(Promise:D $close?) is json-rpc(:async) {
        supply {
            whenever Supply.interval(1) {
                emit {
                    :namespace<tick-tock>,
                    params => %( time => now )
                }
            }
            with $close {
                whenever $close -> $req {
                    my $close-code = (await $req.body).read-uint16(0);
                    self.cleanup($close-code);
                }
            }
        }
    }

### Ad-Hoc Modifier `:wsclose`

This is another way to react to WebSocket close event. A method marked with this modifier will be called whenever WebSocket is closed by the client. The only argument passed to the method is the close code as given by the client:

    method websocket-closed(Int:D $code) is json-rpc(:wsclose) {
        self.cleanup($code);
    }

### Ad-Hoc Modifier `:last`

`:last` methods are invoked when the incoming [`Supply`](https://docs.raku.org/type/Supply) of WebSocket requests is closed.

The object mode of operations is handled by an asynchronous code similar to this pseudo-code:

    supply {
        when $in -> $websocket-request {
            ... # Find a method on the object and call it with $websocket-request.params
            LAST {
                ... # Get all :last methods and call them.
            }
        }
    }

### Ad-Hoc Modifier `:close`

A `:close` method is invoked when the supply block processing WebSocket requests is closed. Done by `CLOSE` phaser on `supply {...}` from the previous section.

### Modifier `:auth(Any:D $auth-obj)`

Non ad-hoc modifier. Defines an authorization object associated with a JSON-RPC exported method. See the section about method call authorization for more details.

`is json-rpc-actor` Class/Role Trait
------------------------------------

It is not normally required to mark a class as a JSON-RPC actor explicitly because applying `json-rpc` trait to a method does it implicitly for us. In practice, this means that the class' `HOW` gets mixed in with `Cro::RPC::JSON::Metamodel::ClassHOW` role. But if we inherit from an actor class the child's `HOW` doesn't get the mixin. `Cro::RPC::JSON` can work with the child as well as with its parent, but sometime we may want the child to be formally declared an actor too. This is when `is json-rpc-actor` comes to help.

### `:auth(Any:D $auth-obj)`

`:auth` modifier defines actor's default authorization object. If a JSON-RPC method doesn't have one associated with it (see `:auth` of `json-rpc` trait) then the default one is used.

NOTES
=====

Consuming A Role With JSON-RPC Methods
--------------------------------------

A role cannot be a JSON-RPC actor. But if a method in it has `json-rpc` trait applied the role becomes a JSON-RPC actor implementation. But a class consuming the role becomes an actor implicitly.

Cro's `request` Object
----------------------

One way or another every JSON-RPC request is bound to a HTTP request not matter of the underlying transport. For this reason a number of classes in `Cro::RPC::JSON` provide `request` accessor which contains an instance of [`Cro::HTTP::Request`](https://cro.services/docs/reference/cro-http-request) which started the current JSON-RPC pipeline. Also, Cro's `request` term provides access to the object wherever applicable.

Note that for WebSockets transport the request object is the one about the initial HTTP request which was then upgraded. It can be used, for example, to validate the HTTP session "owning" the current WebSockets connection.

ERROR HANDLING
==============

`Cro::RPC::JSON` tries to do as much as possible to handle any server-side errors and report them back to the client in a most reasonable way. I.e. if server code dies while processing a method call the client will receive a JSON-RPC object with `error` key with correct error code, error message, and some additional data like server-side exception name and backtrace. But the thing to be remembered: all this related to the synchronous mode of operation only, which also includes actor classes method calls.

The asynchronous mode is totally different here. Due to comparatively low-level approach, code in this mode has to take care of own exceptions. Otherwise if any exception gets leaked it breaks the processing pipeline and results in HTTP 500 response or in WebSocket closing with 1011. This is related to all cases, where a `Supply` is returned by a code, even to `:async` methods.

SEE ALSO
========

[`Cro`](https://cro.services), [`Cro::RPC::JSON::Message`](JSON/Message.md), [`Cro::RPC::JSON::Request`](JSON/Request.md), [`Cro::RPC::JSON::MethodResponse`](JSON/MethodResponse.md), [`Cro::RPC::JSON::Notification`](JSON/Notification.md)

AUTHOR
======

Vadim Belman <vrurg@cpan.org>

LICENSE
=======

Artistic License 2.0

See the LICENSE file in this distribution.

