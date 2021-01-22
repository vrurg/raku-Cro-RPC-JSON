use v6.d;
unit module Cro::RPC::JSON:ver<0.1.0>:auth<cpan:VRURG>:api<2>;

use Cro::HTTP::Router;
use Cro::WebSocket::Message;
use Cro::HTTP::Router::WebSocket;
use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Notification;
use Cro::RPC::JSON::Request:api<2>;
use Cro::RPC::JSON::RequestParser::HTTP;
use Cro::RPC::JSON::RequestParser::WebSocket;
use Cro::RPC::JSON::ResponseSerializer::HTTP;
use Cro::RPC::JSON::ResponseSerializer::WebSocket;
use Cro::RPC::JSON::Handler:api<2>;

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

Which will result in invoking the first C<bar> multi-candidate with named parameter C<:a<string>>. But if we pass an array
together with C<params> key: C<[42, 3.1415926, "anything"]> – then the second multi-candidate will be called with three
positional arguments. This is the basic rule of translation used by C<Cro::RPC::JSON>: a top-level JSON object is
translated into named parameters; a top-level array represents positional parameters.

At lower levels of the C<params> data stucture C<Cro::RPC::JSON> currentlty only supports passing simple values and basic
data structures like objects/hashes and arrays, with accordance to L<JSON|https://www.json.org> specification. Possible
marshalling/unmarshalling of JSON is considered but not implemented yet.

Whatever is returned by the method gets JSONified, wrapped into a valid JSON-RPC response object and returned to the
client via the means of HTTP or WebSocket protocols. Any exceptions thrown and uncaught by user code are handled and
valid JSON-RPC error response is returned to the client.

More information about exporting methods for JSON-RPC is provided in C<json-rpc> trait section below.

Handling a JSON-RPC request by a code object is considered more low-level approach. Particular format of the code is
determined by wether it operates in synchronous or asynchronous mode (see below), general principle is: the code is
provided with a
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Request.md>
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
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Request.md>
instance, or in a "prepared" form as method arguments. One way or another, a JSONifiable response is produced and that's
the end of the cycle for server-side user code.

In asynchronous mode things are pretty much different. First of all, it's not supported for objects; though they still
can provide asynchronous notifications using C<json-rpc> trait C<:async> argument. Second, a code in asynchronous mode
receives a L<C<Supply>|https://docs.raku.org/type/Supply> of incoming requests as an argument and must return a supply
emitting
L<C<Cro::RPC::JSON::MethodResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/MethodResponse.md>
objects. This is the lowest mode of operation as in this case the code is plugged almost directly into a
L<C<Cro>|https://cro.services> pipeline. See C<respond> helper method in
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Request.md>
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



B<Note> that the same asynchronous code can be used for processing a HTTP request too. In this case C<:web-socket>
argument is not used, C<get> turns into C<post>, yet otherwise the code remains unchanged. But what remains the same is
that C<$in> would emit exactly one request object corresponding to the single HTTP C<POST>. So, the only case when this
approach makes sense if when same code object is re-used for both WebSocket and HTTP modes.

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
L<C<Cro::RPC::JSON::MethodResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/MethodResponse.md>
or
L<C<Cro::RPC::JSON::Notification>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Notification.md>
containers. Besides, when it comes to responding to a method call in the asynchronous model the order of responses is
not determined. That's why use of C<$req.respond> ensures that the data emitted has the right C<id> field set in
JSON-RPC response object.

=head2 C<jrpc-request>

Returns currently being processed
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Request.md>
object where applicable and the object is not directly available. Mostly useful for methods of actor class.

=head2 C<jrpc-response>

Returns currently being processed
L<C<Cro::RPC::JSON::MethodResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/MethodResponse.md>
object where applicable and the object is not directly available. Mostly useful for methods of actor class. Also
available as C<jrpc-request.response>.

=head2 C<jrpc-protocol>

A string representing the current transport protocol. Only one of two values is available: I<HTTP> or I<WebSocket>.

=head2 C<jrpc-async>

A L<C<Bool>|https://docs.raku.org/type/Bool> which is I<True> if the code object passed to C<json-rpc> subroutine is detected as asynchronous. For
object mode of operation it is always I<False> for JSON-RPC methods and always I<True> for C<:async> and C<:wsclose>
methods (see C<json-rpc> trait section below).

B<Note> that both C<jrpc-protocol> and C<jrpc-async> are only available outside of C<supply> block of asynchronous
code objects. Similarly, C<jrpc-request> and C<jrpc-response> are not available in asynchronous mode.

=head2 C<jrpc-notify>

This subroutine is a conivenience means to reduce the boilerplate of asynchronous code emitting notifications. All it
does is wraps it's argument into a
L<C<Cro::RPC::JSON::Notification>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Notification.md>
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

Methods exported for JSON-RPC are invoked with parameters received from a JSON-RPC request, de-JSONified, and flattened.
In other words it can be illustrated with:

    $actor.jrpc-method( |from-json($json-params) );

Apparently, this turns any JSON array into positional parameters; and any JSON object into named parameters. Due to the
limitations of JSON format, there is no way to pass both named and positionals at the same time.

The only exception from this rule are methods with a single parameter typed with
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Request.md>.
This way the server code indicates that it wants to do in-depth analysis of the incoming requests and expects a raw
request object. In this case the method cannot be a C<multi> to prevent possible ambiguities.

I<TODO>. Automatic marshalling/unmarshalling is considered for methods with a single parameter. But what'd be the best
way to implement this functionality is yet to be decided.

=head2 C<is json-rpc> Trait

In its most simplistic form the trait simply marks a method and exports it for JSON-RPC calls under the same name it is
declared in the actor class. But sometimes we need to export it under a different name than the one available for Raku
code. In this case we can pass the desired name as trait's first positional argument:

    method add(Int:D $a, Int:D $b) is json-rpc("sum") { $a + $b }

Now we would have to replace I<"add"> string in the last JavaScript example with I<"sum">.

The trait also accepts a number of named arguments which are going to be discussed next. They're called I<modificators>
as they modify the way the methods are treated by C<Cro::RPC::JSON> core. It is important to remember that a method
marked with a modificator is not available for JSON-RPC calls unless its name is explicitly provided. For example:

    method helper() is json-rpc(:async) { ... }                 # Not available for JSON-RPC
    method universal(...) is json-rpc("foo", :async) { ... }    # Available from JSON-RPC as method 'foo'

Though it's pretty much bad idea to use a non-multi method with both name and a modificator because they might have
conflicting set of arguments passed. A better approach would be to apply the trait to a C<proto>:

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

Following are sections about the currently implemented trait modificators.

=head3 C<:async>

C<:async> modificator must be used with methods providing asynchronous events for WebSocket transport. Rules similar to
L<C<json-rpc>|#json-rpc> C<:async> named argument apply:

=item the method must return a supply emitting either
 L<C<Cro::RPC::JSON::Notification>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Notification.md>
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

=head3 C<:wsclose>

This is another way to react to WebSocket close event. A method marked with this modificator will be called whenever
WebSocket is closed by the client. The only argument passed to the method is the close code as given by the client:

    method websocket-closed(Int:D $code) is json-rpc(:wsclose) {
        self.cleanup($code);
    }

=head3 C<:last>

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

=head3 C<:close>

A C<:close> method is invoked when the supply block processing WebSocket requests is closed. Done by C<CLOSE> phaser on
C<supply {...}> from the previous section.

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
                    Cro::RPC::JSON::RequestParser::HTTP.new,
                    Cro::RPC::JSON::Handler.new(&block, :protocol<HTTP>),
                    Cro::RPC::JSON::ResponseSerializer::HTTP.new,
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
    web-socket -> $in, $close {
        my %hparams = :$close, :protocol<WebSocket>;
        with &async {
            %hparams<async> = Supply(&async( $close ));
        }
        my Cro::Transform $pipeline =
            Cro.compose(label => "WebSocket JSON-RPC Handler",
                        Cro::RPC::JSON::RequestParser::WebSocket.new,
                        Cro::RPC::JSON::Handler.new(&block, |%hparams),
                        Cro::RPC::JSON::ResponseSerializer::WebSocket.new,
                );
        $pipeline.transformer($in)
    }
}

multi sub json-rpc ( Any:D $obj, Bool :ws(:web-socket($websocket)) ) {
    my sub obj-handler ( Supply:D $in, Promise $close? ) {
        supply {

            my sub call-phaser-methods( Str:D $mod, |c ) {
                for $obj.^adhoc-methods($mod) -> &meth {
                    $obj.&meth: |c
                }
            }

            whenever $in -> $req {
                my $method = $obj.^json-rpc-find-method($req.method);
                unless $method {
                    $req.respond:
                        exception => X::Cro::RPC::JSON::MethodNotFound.new(
                            msg => "JSON-RPC method " ~ $req.method ~ " is not implemented by " ~ $obj.^name,
                            data => %( method => $req.method),
                            );
                    next
                }

                my $signature = $method.signature;
                my $params;

                # Only use jrpc request object as a parameter if method accepts it. Multi-methods will never receive the
                # object, only the parameters.
                if $method.candidates[0].multi
                   or ( $signature.arity != 2
                        # 2 because method's arity includes self
                        or $signature.count != 2
                        or $signature.params[1].type !~~ Cro::RPC::JSON::Request
                   )
                {
                    $params = $req.has-params ?? $req.params !! Empty;
                }
                else {
                    $params = [$req];
                }

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

                    my $*CRO-JRPC-PROTOCOL = $websocket ?? 'WebSocket' !! 'HTTP';
                    my $*CRO-JRPC-ASYNC = False;
                    $req.respond: $obj.$method(|$params);
                }
                LAST { call-phaser-methods 'last' }
            }
            if $websocket {
                my $*CRO-JRPC-PROTOCOL = 'WebSocket';
                my $*CRO-JRPC-ASYNC = True;

                with $obj.^adhoc-methods("wsclose") -> @cmethods {
                    whenever $close -> $req {
                        my $*CRO-JRPC-REQUEST = $req;
                        my $close-code = ( await $req.body ).read-uint16(0);
                        for @cmethods -> &cmeth {
                            $obj.&cmeth($close-code);
                        }
                    }
                }

                for $obj.^async-methods -> &meth {
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

sub jrpc-notify( Any:D $event ) is export {
    emit Cro::RPC::JSON::Notification.new(:json-body( $event ));
}

BEGIN {
    multi trait_mod:<is>( Method:D \meth, Bool:D :$json-rpc! ) is export {
        Cro::RPC::JSON::Utils::apply-trait( meth, :name( meth.name ) );
    }

    multi trait_mod:<is>( Method:D \meth, Str:D :$json-rpc! ) is export {
        Cro::RPC::JSON::Utils::apply-trait( meth, :name( $json-rpc ) );
    }

    multi trait_mod:<is>( Method:D \meth, Hash:D( List:D( Pair:D ) ) :$json-rpc! ) is export {
        Cro::RPC::JSON::Utils::apply-trait( meth, $json-rpc<> );
    }

    multi trait_mod:<is>( Method:D \meth, :$json-rpc! ( Str:D $name, *%params ) ) is export {
        Cro::RPC::JSON::Utils::apply-trait( meth, %params, :$name );
    }
}

=begin pod

=head1 VERSIONS

=head2 v0.1.0

The module has undergone major rewrite in this version. Most notable changes are:

=item Introduced WebSockets support, including pushing notifications back to clients
=item Added complete support for parameterized roles
=item Added different mode of operations
=item Changes in API this module provides require it to get C<:api<2>> adverb.

=head1 SEE ALSO

L<C<Cro>|https://cro.services>,
L<C<Cro::RPC::JSON::Message>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Message.md>,
L<C<Cro::RPC::JSON::Request>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Request.md>,
L<C<Cro::RPC::JSON::MethodResponse>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/MethodResponse.md>,
L<C<Cro::RPC::JSON::Notification>|https://github.com/vrurg/raku-Cro-RPC-JSON/blob/v0.1.0/docs/md/Cro/RPC/JSON/Notification.md>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
