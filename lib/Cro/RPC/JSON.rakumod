use v6.d;
unit module Cro::RPC::JSON:ver<0.1.5>:auth<zef:vrurg>:api<2>;

use Cro::HTTP::Router;
use Cro::WebSocket::Message;
use Cro::HTTP::Router::WebSocket;
use Cro::RPC::JSON::Auth;
use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Notification;
use Cro::RPC::JSON::Request:api<2>;
use Cro::RPC::JSON::RequestParser::HTTP;
use Cro::RPC::JSON::RequestParser::WebSocket;
use Cro::RPC::JSON::ResponseSerializer::HTTP;
use Cro::RPC::JSON::ResponseSerializer::WebSocket;
use Cro::RPC::JSON::Handler:api<2>;
use Cro::RPC::JSON::Unmarshal;

=begin pod
=head1 NAME

C<Cro::RPC::JSON> - server side JSON-RPC 2.0 in minutes

=head1 SYNOPSIS

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

=head1 DESCRIPTION

The initial and primary purpose of this module is to provide a fast path to make your class-based API implementation
available to serve L<JSON-RPC 2.0|https://www.jsonrpc.org/specification> requests over both HTTP/POST and WebSocket
protocols with as little pain as possible. In many cases it is feasible to use the same method to serve both your Raku
code and JSON-RPC calls without any special case code paths in the method implementation.

Alongside with supporting class-based API implementation the module also supports code-based scenarios where JSON-RPC
requests are handled by a single user-provided code object like a pointy block or a C<sub>. This case has two modes of
operation: synchronous and asynchronous. These will be discussed later.

=head2 Modes Of Operation

C<Cro::RPC::JSON> supports the following modes of operation in mutually exclusive pairs:

=item code or object
=item HTTP or WebSocket
=item synchronous or asynchronous

=head3 Code vs. Object

The L<#SYNOPSIS> provides examples for both of the modes. For any relatively complex API object mode would be preferred
over code for its higher abstraction level and, correspondingly, for better maintainabilty.

Declaring a class for serving a JSON-RPC requests is as simple as adding `is json-rpc` trait to some of its methods. If
we consider `JRPC-Actor` class from L<#SYNOPSIS> then calling its method `bar` from a remote client would be done with
the following JSON structure:

    {
        jsonrpc: "2.0",
        id: 314,
        method: "bar",
        params: { a: "string" }
    }

Which will result in invoking the first C<bar> multi-candidate with named parameter C<:a<string>>. But if we pass an
array together with C<params> key: C<[42, 3.1415926, "anything"]> – then the second multi-candidate will be called with
three positional arguments. This is the basic rule of translation used by C<Cro::RPC::JSON>: a top-level JSON object is
translated into named parameters; a top-level array represents positional parameters. See more information about
handling of method arguments and return values in the L<#Method Call Convention> section below.

More information about exporting methods for JSON-RPC is provided in C<json-rpc> trait section below.

Handling a JSON-RPC request by a code object is considered more low-level approach. Particular format of the code is
determined by wether it operates in synchronous or asynchronous mode (see below), general principle is: the code is
provided with a
L<C<Cro::RPC::JSON::Request>|JSON/Request.md>
object and must produce JSONifiable return value which is then returned to the client. The L<#SYNOPSIS> provides the
most simple case of a synchronous code object. Any call to JSON-RPC to any method in the example will return:

    {
        jsonrpc: "2.0",
        id: <user-request-id>,
        result: { "to-user": "a string", num: 3.141592653589793 }
    }

=head3 HTTP And WebSocket

The difference between these two modes is in the nature of the protocols: where HTTP supports single request/response,
WebSocket supports continuous flow of requests/responses and bidirectional communication between client and server.
Because handling of an HTTP request is rather easy to understand we're not going to focus much on it. Instead, let's
focus in WebSocket specifics of implemeting JSON-RPC by C<Cro::RPC::JSON>.

First of all, it has to be mentioned that there is no single specification of how JSON-RPC over WebSocket is to be
implemented. C<Cro::RPC::JSON> targetting at supporting L<rpc-websockets|https://github.com/elpheria/rpc-websockets>
implementation for JavaScript.

To handle JSON-RPC request/response protocol a WebSocket stream is considered a bidirectional sequence of JSON objects
or arrays of JSON-RPC batch requests/responses. Any server-side notification pushed toward the client must be a JSON
object and must not contain C<jsonrpc> key.

From the server implementation side of things the above said means that for object mode of operation there is nothing
to be changed in method implementations. Everything is handled automatically and makes no difference with HTTP requests.
For code objects in synchronous mode there is no change either. But for asynchronous ones it is recommended to use
C<jrpc-notify> sub to simplify producing of a valid JSON return. The exact meaning of this statement will be clear
later.

To get your server support WebSocket transport all is needed is two changes in router code: C<get> to be used in place
of C<post>; and C<:web-socket> named argument to be added to call to C<json-rpc>:

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

It is still possible though for both object and synchronous code mode cases to provide async notifications. See
C<:async> in sections dedicated to C<json-rpc> routine and C<json-rpc> trait.

=head3 Synchronous And Asynchronous

Hopefully, by this moment it is clear that in synchronous mode of operation user code receives a request in either raw,
as
L<C<Cro::RPC::JSON::Request>|JSON/Request.md>
instance, or in a "prepared" form as method arguments. One way or another, a JSONifiable response is produced and that's
the end of the cycle for server-side user code.

In asynchronous mode things are pretty much different. First of all, it's not supported for objects; though they still
can provide asynchronous notifications using C<json-rpc> trait C<:async> argument. Second, a code in asynchronous mode
receives a L<C<Supply>|https://docs.raku.org/type/Supply> of incoming requests as an argument and must return a supply
emitting
L<C<Cro::RPC::JSON::MethodResponse>|JSON/MethodResponse.md>
objects. This is the lowest mode of operation as in this case the code is plugged almost directly into a
L<C<Cro>|https://cro.services> pipeline. See C<respond> helper method in
L<C<Cro::RPC::JSON::Request>|JSON/Request.md>
which allows to reduce the number of low-level operations needed to emit a resut.

Here is an example of the most simplisic asynchronous code implementation. Note the strict typing used with C<$in>
parameter. This is how we tell C<Cro::RPC::JSON> about our intention to operate asynchronously:

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



B<Note> that the same asynchronous code can be used for processing an HTTP request too. In this case C<:web-socket>
argument is not used, C<get> turns into C<post>, yet otherwise the sample doesn't change. But what remains the same is
that C<$in> would emit exactly one request object corresponding to the single HTTP C<POST>. So, the only case when this
approach makes sense if when the same code object is re-used for both WebSocket and HTTP modes.

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

First of all, the absense of C<Supply> in front of C<$in> is not an error here. Another way to request asynchronous
mode of operation is to use declare two parameters. In this case the second one is expected to be a close
L<C<Promise>|https://docs.raku.org/type/Promise> as provided by
L<C<Cro::HTTP::Router::WebSocket>|https://cro.services/docs/reference/cro-http-router-websocket#Receiving_close_messages>.

The last C<whenever> block apparently produces a notification every second which is then pushed back to the client.

C<Cro::RPC::JSON> also provides a hybrid mode of operation where it is possible to provide asynchronous events alongside
with a synchronous code. See C<:async> argument of C<json-rpc> trait and C<json-rpc> sub.

=head1 MODULE HELPERS

=head2 C<json-rpc>

C<json-rpc> is a multi-dispatch C<sub> which must be used inside C<Cro> C<get> or C<post> blocks, depending on what
transport protocol, HTTP or WebSockets, is to be served. In its most simplistic form C<json-rpc> takes a single code
object:

    json-rpc -> $req { ... }

Or:

    json-rpc -> Supply $in { ... }

As it was noted above, the type of argument determines wether the code block is to operate in synchronous or
asynchronous mode.

Adding a named argument C<:web-socket> would tell C<json-rpc> to wrap around C<Cro>'s C<web-socket> subroutine. Same rules
about synchronous/asynchronous mode of operation apply:

    json-rpc :web-socket, -> $req { ... }
    json-rpc :web-socket, -> Supply $in { ... }
    json-rpc :web-socket, -> $in, $close { ... }

 I<C<:web-socket> is also available as C<:ws> or C<:websocket> aliases.>

If the first positional argument of C<json-rpc> is anything but a code then it is expected to be an object providing
methods for JSON-RPC calls. I.e. those marked with C<is json-rpc> trait:

    class JRPC-Actor {
        method authorise(Str:D $name, Str:D $password) is json-rpc { ... }
    }
    route {
        my $actor = JRPC-Actor.new;
        get -> "api" {
            json-rpc $actor;
        }
    }

The C<$actor> object can also be accompanied with C<:web-socket> (C<:ws>, C<:websocket>) argument.

=head3 C<:async>

When a synchronous code is used with C<:web-socket> argument it is still possible to emit asynchronous notifications.
This is done by passing C<:async> named argument to the subroutine which is expected to be a code block which can accept
a single argument – WebSocket C<$close> L<C<Promise>|https://docs.raku.org/type/Promise>; and which will return a
L<C<Supply>|https://docs.raku.org/type/Supply>. The supply is expected to emit JSONifiable notifications to be pushed
back to the client code. For example, this is a code from I<060-websocket.rakutest> test file:

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

This little trick allows us to use same synchronous code for serving both HTTP and WebSocket protocols while still allow
for asynchronous operations with WebSockets.

This mode of operation is called I<hybrid> because it combines both synchronous and asynchronous ones.

B<Note> that contrary to the asynchronous code above we don't use C<jrpc-notify> to emit a notification. This is because
in the case of asynchronous code there is no way for C<Cro::RPC::JSON> core to tell the difference between a reponse to
a JSON-RPC method call or a notification if they both are hashes, for example, as both are coming from the same supply.
That's why one have to wrap them in either
L<C<Cro::RPC::JSON::MethodResponse>|JSON/MethodResponse.md>
or
L<C<Cro::RPC::JSON::Notification>|JSON/Notification.md>
containers. Besides, when it comes to responding to a method call in the asynchronous model the order of responses is
not determined. That's why use of C<$req.respond> ensures that the data emitted has the right C<id> field set in
JSON-RPC response object.

=head2 C<jrpc-request>

Returns currently being processed
L<C<Cro::RPC::JSON::Request>|JSON/Request.md>
object where applicable and the object is not directly available. Mostly useful for methods of actor class.

=head2 C<jrpc-response>

Returns currently being processed
L<C<Cro::RPC::JSON::MethodResponse>|JSON/MethodResponse.md>
object where applicable and the object is not directly available. Mostly useful for methods of actor class. Also
available as C<jrpc-request.jrpc-response>.

=head2 C<jrpc-protocol>

A string representing the current transport protocol. Only one of two values is available: I<HTTP> or I<WebSocket>.

=head2 C<jrpc-async>

A L<C<Bool>|https://docs.raku.org/type/Bool> which is I<True> if the code object passed to C<json-rpc> subroutine is
detected as asynchronous. For object mode of operation it is always I<False> for JSON-RPC methods and always I<True> for
C<:async> and C<:wsclose> methods (see C<json-rpc> trait section below).

B<Note> that both C<jrpc-protocol> and C<jrpc-async> are only available outside of C<supply> block of asynchronous
code objects. Similarly, C<jrpc-request> and C<jrpc-response> are not available in asynchronous mode.

=head2 C<jrpc-notify>

This subroutine is a conivenience means to reduce the boilerplate of asynchronous code emitting notifications. All it
does is wraps it's argument into a
L<C<Cro::RPC::JSON::Notification>|JSON/Notification.md>
instance and calls C<emit> with the object.

=head1 CREATING AN ACTOR CLASS

Writing an actor class is the most advanced and the most simple way of implementing a complex API. As it was already
stated before, the biggest I<pro> of this approach is abstracting API implementation from the means of accessing it.
In other words, normally it is sufficient to have:

    use Cro::RPC::JSON:api<2>;
    class JRPC-Actor {
        method add(Int:D $a, Int:D $b) is json-rpc { $a + $b }
    }

The method is then available for both L<Raku|https://raku.org> on the server side as:

    my $sub = $actor.add(13, 42);

And for the client code in JavaScript running in a browser:

    let WebSocket = require('rpc-websockets').Client;
    let ws = new WebSocket('ws://localhost:3000');
    let sum = await ws.call("add", [13, 42]);

Similar JavaScript code can be imagined for any alternative client-side JSON-RPC implementation.

Apparently, all one needs is to use C<is json-rpc> trait to mark a method as a JSON-RPC compatible.

B<Note> that while we mostly talk about an I<actor class> the trait can also be applied to methods in roles. Consuming
such role turns a class into a JSON-RPC actor implementation automatically. Inheriting from an actor class also
preserves access to the JSON-RPC methods unless they're redefined in a child class without C<is json-rpc> trait.
I<t/005-trait.rakutest> test can be very helpful in providing examples of how things work with Raku OO model.

=head2 Method Call Convention

Methods exported for JSON-RPC are invoked with parameters received from a JSON-RPC request, de-serialized, and
flattened. In other words it can be illustrated with:

    $actor.jrpc-method( |from-json($json-params) );

Apparently, this turns any JSON array into positional parameters; and any JSON object into named parameters. Due to the
limitations of JSON format, there is no way to pass both named and positionals at the same time.

The only exception from this rule are methods with a single parameter typed with
L<C<Cro::RPC::JSON::Request>|JSON/Request.md>.
This way a method indicates that it wants to do in-depth analysis of the incoming requests and expects a raw request
object.

For developer conivenience the module provides automated serialization of method's return values and de-serialization of
arguments. With this feature it's event more easy to write methods universal for both Raku and RPC side of things; and
even less boilerplate for any kind of thunk methods.

The most simple case is serialization of return values. It's done in a very straightforward way: a method return is
passed to C<JSON::Marshal::marshal> sub. The outcome is then sent back to the RPC client.

Somewhat more complicate approach is used for method arguments recived via C<params> key of JSON-RPC request. First of
all, the module checks if C<params> is an array. And if it is then it is considered as a list of positional arguments.
This is an unbendable rule.

If C<params> is a JSON object and the callee method doesn't have a positional parameter then C<params> is considered a
set of named arguments. Otherwise it's considered to be the only positional argument of the method.

Before submitting the arguments to the method C<Cro::RPC::JSON> first tries to de-serialize them based on method's
signature and parameter typing. The algorithm used is basically identical for both positionals and nameds: the module
iterates over arguments, matches them to method parameters, and then C<JSON::Unmarshal::unmarshal()> with parameter's
type. For example:

    class Product {
        has Int $.SKU;
        has Str $.name;
    }
    method to-inventory(Product:D $item, Int:D $count) is json-rpc { ... }

When C<to-inventory> is invoked via this JSON-RPC request:

    {
        id: 1,
        jsonrpc: "2.0",
        method: "to-inventory",
        params: [
            { SKU: 42, name: "Traveller's Towel" },
            13
        ]
    }

the first object in C<params> array will be de-serialized into a C<Product> instance. That's it, we now have method
which can be transparently used by both Raky and RPC callers!

If the method is changed to use named parameters:

    method to-inventory(Product:D :$item, Int:D :$count) is json-rpc {...}

Then C<params> must be turned into a JSON object like this:

    {
        item: { SKU: 42, name: "Traveller's Towel" },
        count: 13
    }

And the outcome will be no different of the positional variant.

Aliasing of named parameters is supported. With this signature:

    method to-inventory(Product:D :product(:$item), Int:D :$count) is json-rpc {...}

We can use the following C<params> JSON object:

    {
        product: { SKU: 42, name: "Traveller's Towel" },
        count: 13
    }

C<Any> type is special cased here. Parameters of C<Any> type receive corresponding arguments from the request as-is,
no unmarshaling attempted beyond de-stringification of a JSON entity:

    method foo($x, $y) is json-rpc {...}

    params: [true, { a: 1 }]

C<$x> here will be set to I<True>, C<$y> – to hash C<{ a => 1 }>.

It is also possible to pass a single positional array argument with C<params: [[1, 2, 3]]>.

The unmarshalling will also work correctly for parameterized arrays and hashes. So, if we need to add several objects
of the same kind we can do it like this:

    method to-catalog(Product:D @items) is json-rpc {...}

And it will work with:

    params: [
        { SKU: 42, name: "Traveller's Towel" },
        { SKU: 13, name: "A Happy Amulet" },
        { SKU: 256, name: "Product 100000000" }
    ]

C<to-catalog> will receive an array of C<Product> instances.

Slurpy parameters are supported as well as captures. The module doesn't attempt unmarshalling of arguments to be
consumed by slurpies or captures because there is no way for us to know their types.

The situation is pretty much identical for multi-dispatch methods where to know the eventual candidate to be invoked
we nede to know argument types; but we can't know them because we don't know the candidate! For this reason
de-serialization is only done based on C<proto> method signature:

    proto method categorize-product(Product:D, |) is json-rpc {*}
    multi method categorize-product(Product:D $item, Str:D $category-name) {...}
    multi method categorize-product(Product:D $item, Int:D $category-id) {...}

    params: [{ SKU: 42, name: "Traveller's Towel" }, "fictional"]
    params: [{ SKU: 13, name: "A Happy Amulet" }, 12]

Apparently, each of the C<params> will dispatch as expected.

=head2 Authorizing Method Calls

C<Cro::RPC::JSON> provide means to implement session-based authorization of a method call. It is based on the following
two key components:

=item Session object, as L<documented in a Cro paper|https://cro.services/docs/http-auth-and-sessions>, available via
    C<request.auth>. The object must consume
    L<C<Cro::RPC::JSON::Auth>|JSON/Auth.md>
    role and implement C<json-rpc-authorize> method
=item Authorization object provided with C<:auth> modifier of either C<json-rpc> or C<json-rpc-actor> traits (see below)

The Cro's session object used to authenticate/authorize a HTTP session or a WebSocket connection is expected to provide
means of authorizing JSON-RPC method calls too. For this purpose it is expected to consume
L<C<Cro::RPC::JSON::Auth>|JSON/Auth.md>
role and implement C<json-rpc-authorize> method. Generally speaking, the method is expected to either authorize or
prohit an RPC method call based on the available session data. For example, here is an implementation of the session
object from a test suite:

    my class SessionMock does Cro::RPC::JSON::Auth does Cro::HTTP::Auth {
        method json-rpc-authorize($meth-auth) {
            return False if $meth-auth eq 'admin';
            return True if $meth-auth eq 'user' | 'group';
            die "Can't authorize with ", $meth-auth, ": no such privilege";
        }
    }


This one is really simplistic. It prohibits any activity if it requires I<admin> privileges; and only allows anything
requiring I<user> or I<group>. Apparently, the real life requires something more sophisticated, depending on the
authorization model of your application.

It is worth mentioning that the auth object associated with a method can be virtually of any type given it's a definite.
For example, it can be a L<C<Junction>|https://docs.raku.org/type/Junction>:

    method self-destroy() is json-rpc(:auth('root' | 'admin')) {...}

Because defining the same auth object for every JSON-RPC method could be really boresome, it is possible to define the
default one by associating it with actor class:

    class Foo is json-rpc-actor(:auth<user>) {
        ...
    }

In this case every JSON-RPC method is considered having I<user> auth associated with them unless otherwise specified
manually per method declaration.

The authorization takes place whenever a definite auth object can be associated with a method. I.e. it could be an
object defined for the method itself; or a default one can be found. Note also that there is no way to bypass
authorization in the latter case.

There are some specifics of the authorization process to be considered when class inheritance is involved:

=item If a class inherits from one or more actor classes but is not formally declared as a JSON-RPC actor itself then
    the first defined auth object found on a parent actor class is used.
=item The found default auth object overrides any other default specified for classes/roles located further in MRO list.
    I.e. if classes C<Foo> and C<Bar> appear in MRO in the order of mentioning; and if C<Foo> uses I<manager> as the
    default auth, whereas C<Bar> default is I<admin>; then any JSON-RPC method from C<Bar> with no explicit auth
    attached will be considered as having it set to I<manager>.

=head2 C<is json-rpc> Method Trait

In its most simplistic form the trait simply marks a method and exports it for JSON-RPC calls under the same name it is
declared in the actor class. But sometimes we need to export it under a different name than the one available for Raku
code. In this case we can pass the desired name as trait's first positional argument:

    method add(Int:D $a, Int:D $b) is json-rpc("sum") { $a + $b }

Now we would have to replace I<"add"> string in the last JavaScript example with I<"sum">.

The trait also accepts a number of named arguments which are going to be discussed next. They're called I<modifiers>
as they modify the way the methods are treated by C<Cro::RPC::JSON> core. It is important to remember that some
modifiers make a method unavailable for JSON-RPC calls:

    method helper() is json-rpc(:async) { ... }                 # Not available for JSON-RPC

Methods marked wit these modifiers become I<ad-hoc> methods; the modifiers are correspondingly called I<ad-hoc> too. One
of the features making ad-hoc methods different from JSON-RPC exports is that they're not overridable in child classes.
In other words, if class C<Foo> inherits from C<Bar> and both define a C<:async> ad-hoc named C<event-emitter> then
both methods will be incorporated into JSON-RPC pipeline. This feature makes C<submethod>s ideal candidates for ad-hoc
implementation.

Though it's pretty much a bad idea, but if an ad-hoc method is given a name then it becomes a JSON-RPC export too. If
for some reason a developer considers this approach then it is better be done by means of a multi-dispatch via applying
the trait to method's C<proto>:

    proto method universal(|) is json-rpc("foo", :async) {...}
    multi method universal(Promise:D $close) { ... }  # Take care of :async
    multi method universal(|c) {...} # Take care of API calls.

It is also worth mentioning that applying the trait to a C<multi> candidate is equivalent to applying it to its
C<proto>. While being generally useless withing a class, it allows us to turn a method of parent class into a JSON-RPC
accessible one:

    class Foo {
        has $.value;
        proto method add(|) {*}
        multi method add(::?CLASS:D $b) { $!value += $b.value }
        ...
    }
    class Bar is Foo {
        multi method add($a, $b) is json-rpc { $!value = $a.value + $b.value }
    }

So, it is now possible to use the single-argument version of C<add> method by a remote client too.

=head3 Ad-Hoc Modifier C<:async>

C<:async> modifier must be used with methods providing asynchronous events for WebSocket transport. Rules similar
to L<C<json-rpc>|#json-rpc> C<:async> named argument apply:

=item the method must return a supply emitting either
 L<C<Cro::RPC::JSON::Notification>|JSON/Notification.md>
 instances or JSONifiable objects
=item the method may have a single parameter – the WebSocket C<$close> L<C<Promise>|https://docs.raku.org/type/Promise>

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

=head3 Ad-Hoc Modifier C<:wsclose>

This is another way to react to WebSocket close event. A method marked with this modifier will be called whenever
WebSocket is closed by the client. The only argument passed to the method is the close code as given by the client:

    method websocket-closed(Int:D $code) is json-rpc(:wsclose) {
        self.cleanup($code);
    }

=head3 Ad-Hoc Modifier C<:last>

C<:last> methods are invoked when the incoming L<C<Supply>|https://docs.raku.org/type/Supply> of WebSocket requests is closed.

The object mode of operations is handled by an asynchronous code similar to this pseudo-code:

    supply {
        when $in -> $websocket-request {
            ... # Find a method on the object and call it with $websocket-request.params
            LAST {
                ... # Get all :last methods and call them.
            }
        }
    }

=head3 Ad-Hoc Modifier C<:close>

A C<:close> method is invoked when the supply block processing WebSocket requests is closed. Done by C<CLOSE> phaser on
C<supply {...}> from the previous section.

=head3 Modifier C<:auth(Any:D $auth-obj)>

Non ad-hoc modifier. Defines an authorization object associated with a JSON-RPC exported method. See the section about
method call authorization for more details.

=head2 C<is json-rpc-actor> Class/Role Trait

It is not normally required to mark a class as a JSON-RPC actor explicitly because applying C<json-rpc> trait to a
method does it implicitly for us. In practice, this means that the class' C<HOW> gets mixed in with
C<Cro::RPC::JSON::Metamodel::ClassHOW> role. But if we inherit from an actor class the child's C<HOW> doesn't get the
mixin. C<Cro::RPC::JSON> can work with the child as well as with its parent, but sometime we may want the child to be
formally declared an actor too. This is when C<is json-rpc-actor> comes to help.

=head3 C<:auth(Any:D $auth-obj)>

C<:auth> modifier defines actor's default authorization object. If a JSON-RPC method doesn't have one associated with
it (see C<:auth> of C<json-rpc> trait) then the default one is used.

=head1 NOTES

=head2 Consuming A Role With JSON-RPC Methods

A role cannot be a JSON-RPC actor. But if a method in it has C<json-rpc> trait applied the role becomes a JSON-RPC actor
implementation. But a class consuming the role becomes an actor implicitly.

=head2 Cro's C<request> Object

One way or another every JSON-RPC request is bound to a HTTP request not matter of the underlying transport. For this
reason a number of classes in C<Cro::RPC::JSON> provide C<request> accessor which contains an instance of
L<C<Cro::HTTP::Request>|https://cro.services/docs/reference/cro-http-request> which started the current
JSON-RPC pipeline. Also, Cro's C<request> term provides access to the object wherever applicable.

Note that for WebSockets transport the request object is the one about the initial HTTP request which was then upgraded.
It can be used, for example, to validate the HTTP session "owning" the current WebSockets connection.

=head1 ERROR HANDLING

C<Cro::RPC::JSON> tries to do as much as possible to handle any server-side errors and report them back to the client
in a most reasonable way. I.e. if server code dies while processing a method call the client will receive a JSON-RPC
object with C<error> key with correct error code, error message, and some additional data like server-side exception
name and backtrace. But the thing to be remembered: all this related to the synchronous mode of operation only, which
also includes actor classes method calls.

The asynchronous mode is totally different here. Due to comparatively low-level approach, code in this mode has to take
care of own exceptions. Otherwise if any exception gets leaked it breaks the processing pipeline and results in HTTP 500
response or in WebSocket closing with 1011. This is related to all cases, where a C<Supply> is returned by a code, even
to C<:async> methods.

=end pod

proto json-rpc ( | ) is export {*}

multi sub json-rpc ( &block, Bool :ws(:web-socket(:$websocket)) where not * ) {
    my $request = request;
    my $response = response;

    my Cro::Transform $pipeline =
        Cro.compose(label => "JSON-RPC Handler",
                    Cro::RPC::JSON::RequestParser::HTTP.new(:$request),
                    Cro::RPC::JSON::Handler.new(&block, :$request, :protocol<HTTP>),
                    Cro::RPC::JSON::ResponseSerializer::HTTP.new(:$request),
            );
    CATCH {
        $response.set-body(.message ~ "\n" ~ .backtrace);
        $response.remove-header('Content-Type');
        $response.append-header('Content-Type', q[text/plain; charset=utf-8]);

        when X::Cro::RPC::JSON {
            $response.status = .http-code;
        }
        default {
            $response.status = 500;
        }
    };
    react {
        whenever $pipeline.transformer(supply { emit $request }) -> $msg {
            use JSON::Marshal;
            $response.remove-header('Content-Type');
            $response.append-header('Content-Type', q[application/json; charset=utf-8]);
            $response.set-body($msg.json-body);
            $response.status = 200;
        }
    }
}

multi sub json-rpc( &block,
                    Bool :ws(:web-socket(:$websocket)) where so *,
                    :&async )
{
    my $request = request;
    web-socket -> $in, $close {
        my %hparams = :$close, :protocol<WebSocket>, :$request;
        with &async {
            %hparams<async> = Supply(&async( $close ));
        }
        my Cro::Transform $pipeline =
            Cro.compose(label => "WebSocket JSON-RPC Handler",
                        Cro::RPC::JSON::RequestParser::WebSocket.new(:$request),
                        Cro::RPC::JSON::Handler.new(&block, |%hparams),
                        Cro::RPC::JSON::ResponseSerializer::WebSocket.new(:$request),
                );
        $pipeline.transformer($in)
    }
}

multi sub json-rpc ( Any:D $obj, Bool :ws(:web-socket($websocket)) ) {
    my sub obj-handler ( Supply:D $in, Promise $close? ) {
        supply {

            my sub call-phaser-methods( Str:D $mod, |c ) {
                for json-rpc-adhoc-methods($obj, $mod) -> &meth {
                    $obj.&meth: |c
                }
            }

            whenever $in -> $req {
                my $*CRO-JRPC-REQUEST = $req;
                my $*CRO-ROUTER-REQUEST = $req.request;
                my $*CRO-JRPC-PROTOCOL = $websocket ?? 'WebSocket' !! 'HTTP';
                my $*CRO-JRPC-ASYNC = False;

                my $method = json-rpc-find-method($obj, $req.method);
                unless $method {
                    $req.respond:
                        exception => X::Cro::RPC::JSON::MethodNotFound.new(
                            msg => "JSON-RPC method " ~ $req.method ~ " is not implemented by " ~ $obj.^name,
                            data => %( method => $req.method),
                            );
                    next
                }

                my $req-auth = $req.request.auth;
                # If method doesn't have auth set then pick its class' default
                my $meth-auth = $method.json-rpc-auth // json-rpc-auth($obj);
                # Only authorize if there is auth object for either method or its class.
                with $meth-auth {
                    my $authorized = False;
                    if $req-auth.defined && $req-auth ~~ Cro::RPC::JSON::Auth {
                        $authorized = $req-auth.json-rpc-authorize($meth-auth);
                    }
                    unless $authorized {
                        $req.respond:
                            exception => X::Cro::RPC::JSON::MethodNotFound.new(
                                msg => "Unauthorized access to method '" ~ $req.method ~ "'",
                                data => %( method => $req.method ),
                                );
                        next
                    }
                }

                # === Kind of binding of parameters to the signature ===
                my $signature = $method.signature;
                my @sig-params := $signature.params;
                my $raw-args := $req.has-params && $req.params.defined ?? $req.params !! Empty;
                my $arg-count = $raw-args.elems;
                my $count-with-self = $arg-count + 1; # Remember about invocator argument

                if $raw-args ~~ Positional
                   && ($signature.count < $count-with-self
                       || $signature.arity > $count-with-self)
                {
                    X::Cro::RPC::JSON::InvalidParams.new(
                            msg => "Incorrect number of parameters in call to method '" ~ $req.method ~ "'",
                            data => {
                                :$arg-count,
                                method-accepts => $signature.count,
                                method-expects => $signature.arity,
                            }
                        ).throw
                }

                # Collect all positional and named parameters of a method
                my @sig-pos;
                my %sig-named;
                my $slurpies = 0;

                for @sig-params[1..*] -> $p {
                    last if $p.capture;
                    if $p.slurpy {
                        last if ++$slurpies >= 2;
                        next;
                    }
                    elsif $p.positional {
                        @sig-pos.push: $p;
                    }
                    else {
                        %sig-named{$_} = $p for $p.named_names;
                    }
                }

                my sub maybe-unmarshal($arg, \type) {
                    ($arg ~~ Positional | Associative) && (type.WHAT !=== Any)
                        ?? unmarshal($arg, type.WHAT)
                        !! $arg
                }

                # Build method arguments. The resulting args will all be either positional or nameds. No mixture is
                # allowed because there is no way to represent it in JSON
                my (@arg-pos, %arg-named);
                if +@sig-pos || $raw-args ~~ Positional {
                    # First check if the method expects only a request object
                    if +@sig-pos == 1 && @sig-pos[0].type ~~ Cro::RPC::JSON::Request {
                        @arg-pos.push: $req;
                    }
                    else {
                        my $i = 0;
                        # A single hash object must be treated as a single argument.
                        my @arg-list := $raw-args ~~ Associative ?? ($raw-args,) !! $raw-args.List;
                        while $i < +@sig-pos {
                            my $param := @sig-pos[$i];
                            my $arg = @arg-list[$i];
                            @arg-pos.push: maybe-unmarshal($arg, $param.type);
                            ++$i;
                        }

                        if $i < +@arg-list {
                            @arg-pos.append: @arg-list[$i..*];
                        }
                    }
                }
                else {
                    for $raw-args.kv -> $name, $arg {
                        if %sig-named{$name}:exists {
                            %arg-named{$name} = maybe-unmarshal($arg, %sig-named{$name}.type);
                        }
                        else {
                            %arg-named{$name} = $arg;
                        }
                    }
                }
                # === End of signature binding ===

                do {
                    # Handle exceptions from user code here to make the error reporting more explicit.
                    CATCH {
                        when X::Multi::NoMatch {
                            $req.respond:
                                exception => X::Cro::RPC::JSON::MethodNotFound.new(
                                    msg => "There is no matching variant for multi method '{ $req.method }' on { $obj.WHO }",
                                    data => %( method => $req.method)
                                    )
                        }
                        when X::Cro::RPC::JSON {
                            $req.respond: exception => $_;
                        }
                        default {
                            $req.respond:
                                exception => X::Cro::RPC::JSON::InternalError.new(
                                    msg => ~$_,
                                    data => %(
                                        exception => .^name,
                                        backtrace => ~.backtrace,
                                    ))
                        }
                    }

                    # Make Cro's `request` term work in actor methods
                    $req.respond: $obj.$method(|@arg-pos, |%arg-named);
                }
                LAST { call-phaser-methods 'last' }
            }
            if $websocket {
                my $*CRO-JRPC-PROTOCOL = 'WebSocket';
                my $*CRO-JRPC-ASYNC = True;

                if +(my @cmethods = json-rpc-adhoc-methods($obj, 'wsclose')) {
                    whenever $close -> $req {
                        my $*CRO-JRPC-REQUEST = $req;
                        my $close-code = ( await $req.body ).read-uint16(0);
                        for @cmethods -> &cmeth {
                            $obj.&cmeth($close-code);
                        }
                    }
                }

                for json-rpc-adhoc-methods($obj, 'async') -> &meth {
                    my @pos;
                    if &meth.signature.count > 1 && $close.defined {
                        @pos.push: $close;
                    }
                    my $asupply = $obj.&meth: |@pos;
                    whenever $asupply {
                        if $_ ~~ Cro::RPC::JSON::Notification {
                            emit $_
                        }
                        else {
                            emit Cro::RPC::JSON::Notification.new(:json-body( $_ ));
                        }
                        QUIT {
                            default {
                                emit Cro::WebSocket::Message.new(
                                    opcode => Cro::WebSocket::Message::Close,
                                    fragmented => False,
                                    body-byte-stream => supply {
                                        emit Blob.new([243, 3]);
                                        done;
                                    });
                            }
                        }
                    }
                }
            }

            CLOSE { call-phaser-methods 'close' }
        }
    }

    json-rpc(&obj-handler, :$websocket);
}

sub term:<jrpc-request>( ) is export {
    $*CRO-JRPC-REQUEST //
    X::Cro::RPC::JSON::ServerError.new(
        :msg( "jrpc-request can't be used outside of a json-rpc context" ),
        :code( JRPCNoReqObject ),
        ).throw
}
sub term:<jrpc-response>( ) is export {
    $*CRO-JRPC-RESPONSE //
    X::Cro::RPC::JSON::ServerError.new(
        :msg( "jrpc-request can't be used outside of a json-rpc context" ),
        :code( JRPCNoReqObject ),
        ).throw
}

sub term:<jrpc-protocol>( ) is export {
    $*CRO-JRPC-PROTOCOL // Nil
}
sub term:<jrpc-async>( ) is export {
    $*CRO-JRPC-ASYNC // Nil
}

sub jrpc-notify(Any:D $event) is export {
    emit Cro::RPC::JSON::Notification.new(:json-body( $event ));
}

BEGIN {
    multi trait_mod:<is>(Method:D \meth, Bool:D :$json-rpc!) is export {
        Cro::RPC::JSON::Utils::apply-json-rpc-trait(meth, :name( meth.name ));
    }

    multi trait_mod:<is>(Method:D \meth, Str:D :$json-rpc!) is export {
        Cro::RPC::JSON::Utils::apply-json-rpc-trait(meth, :name( $json-rpc ));
    }

    multi trait_mod:<is>(Method:D \meth, :$json-rpc! ( Str:D $name, *%params )) is export {
        Cro::RPC::JSON::Utils::apply-json-rpc-trait(meth, %params, :$name);
    }

    multi trait_mod:<is>(Method:D \meth, Hash:D( List:D( Pair:D ) ) :$json-rpc!) is export {
        Cro::RPC::JSON::Utils::apply-json-rpc-trait(meth, $json-rpc<>);
    }

    multi trait_mod:<is>(Mu:U \typeobj, Hash:D( List:D( Pair:D ) ) :$json-rpc-actor!) is export {
        Cro::RPC::JSON::Utils::apply-actor-trait(typeobj, $json-rpc-actor<>);
    }

    multi trait_mod:<is>(Mu:U \typeobj, Bool:D :$json-rpc-actor!) is export {
        Cro::RPC::JSON::Utils::apply-actor-trait(typeobj) if $json-rpc-actor;
    }
}

=begin pod

=head1 SEE ALSO

L<C<Cro>|https://cro.services>,
L<C<Cro::RPC::JSON::Message>|JSON/Message.md>,
L<C<Cro::RPC::JSON::Request>|JSON/Request.md>,
L<C<Cro::RPC::JSON::MethodResponse>|JSON/MethodResponse.md>,
L<C<Cro::RPC::JSON::Notification>|JSON/Notification.md>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
