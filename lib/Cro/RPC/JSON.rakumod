use v6.d;
unit module Cro::RPC::JSON:ver<0.0.907>:auth<cpan:VRURG>;

=begin pod
=head1 NAME

C<Cro::RPC::JSON> - convenience shortcut for JSON-RPC 2.0

=head1 SYNOPSIS

    use Cro::HTTP::Server;
    use Cro::HTTP::Router;
    use Cro::RPC::JSON;

    class JRPC-Actor is export {
        method foo ( Int :$a, Str :$b ) is json-rpc {
            return "$b and $a";
        }

        proto method bar (|) is json-rpc { * }

        multi method bar ( Str :$a! ) { "single named Str param" }
        multi method bar ( Int $i, Num $n, Str $s ) { "Int, Num, Str positionals" }
        multi method bar ( *%options ) { [ "slurpy hash:", %options ] }

        method non-json (|) { "I won't be called!" }
    }

    sub routes is export {
        route {
            post -> "api" {
                my $actor = JRPC-Actor.new;
                json-rpc $actor;
            }
            post -> "api2" {
                json-rpc -> Cro::RPC::JSON::Request $jrpc-req {
                    { to-user => "a string", num => pi }
                }
            }
        }
    }

=head1 DESCRIPTION

This module provides a convenience shortcut for handling JSON-RPC requests by exporting C<json-rpc> function to be used
inside a L<Cro::HTTP::Router|https://cro.services/docs/reference/cro-http-router> C<post> handler. The function takes
one argument which could either be a L<C<Code>|https://docs.perl6.org/type/Code.html> object or an instantiated class.

When code object is used:

    json-rpc -> $jrpc-request { ... }

    sub jrpc-handler ( Cro::RPC::JSON::Request $jrpc-request ) { ... }
    json-rpc -> &jrpc-handler;

it is supplied with parsed JSON-RPC request (C<Cro::RPC::JSON::Request>).

When a class instance is used a JSON-RPC call is mapped on a class method with the same name as in RPC request. The
class method must have C<is json-rpc> trait applied (see L<SYNOPSIS|#SYNOPSIS> example). Methods without the trait are
not considered part of JSON-RPC API and calling such method would return -32601 error code back to the caller.

The class implementing the API is called I<JSON-RPC actor class> or just I<actor>.

If the only parameter of a JSON-RPC method has C<Cro::RPC::JSON::Request> type then the method will receive the JSON-RPC
request object as parameter. Otherwise C<params> object of JSON-RPC request is used and matched against actor class
method signature. If C<params> is an object then it is considered a set of named parameters. If it's an array then all
params are passed as positionals. For example:

    params => { a => 1, b => "aa" }

will match to

    method foo ( Int :$a, Str :$b ) { ... }

Whereas

    params => [ 1, "aa" ]

will match to

    method foo( Int $a, Str $b ) { ... }

If parameters fail to match to the method signature then -32601 error would be returned.

To handle various set of parameters one could use either slurpy parameters or C<multi> methods. In second case
the C<is json-rpc> trait must be applied to method's C<proto> declaration.

B<NOTE> that C<multi> method cannot have the request object as a parameter. This is due to possible ambiguity in a
situation when there is a match to one C<multi> candidate by parameters and by the request object to another.

=end pod

use Cro::HTTP::Router;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Utils;
use Cro::RPC::JSON::Request;
use Cro::RPC::JSON::RequestParser;
use Cro::RPC::JSON::ResponseSerializer;
use Cro::RPC::JSON::Handler;

proto json-rpc (|) is export { * }

multi json-rpc ( Code $block ) {
    #note "Creating pipeline with handler ", $block;

    # note "JSON-RPC CRO-ROUTER-RESPONSE: ", $*CRO-ROUTER-RESPONSE // "*not defined*";
    my $request = request;
    my $response = response;

    my Cro::Transform $pipeline =
        Cro.compose(label => "JSON-RPC Handler",
                    Cro::RPC::JSON::RequestParser.new,
                    Cro::RPC::JSON::Handler.new($block),
                    Cro::RPC::JSON::ResponseSerializer.new,
            );
    #note "GEN RESPONSE";
    CATCH {
        # note "PROCESSING EXCEPTION ", $_.WHO, " ", ~$_, $_.backtrace;
        when X::Cro::RPC::JSON {
            #note "STATUS CODE FROM EXCEPTION: ", $_.http-code;
            $response.status = $_.http-code;
        }
        default {
#            note "CAUGHT EXCEPTION [{.^name}]: ", .message, "\n", ~.backtrace;
            $response.status = 500;
            content 'text/plain', '500 ' ~ .message;
        }
    };
    react {
        whenever $pipeline.transformer( supply { emit $request } ) -> $msg {
            # note "MSG: ", $msg.perl;
            # note "REACT IN JSON-RPC CRO-ROUTER-RESPONSE: ", $*CRO-ROUTER-RESPONSE // "*not defined*";
            $response.append-header('Content-type', qq[application/json; charset=utf-8]);
            $response.set-body($msg.json-body);
            $response.status = 200;
        }
    }
}

multi json-rpc ( $obj ) {
    my sub obj-handler ( $req ) {
        #note "JRPC method {$req.method} on ", $obj.WHO;
        my $method = $obj.^json-rpc-find-method($req.method);
        unless $method {
            X::Cro::RPC::JSON::MethodNotFound.new(
                msg => "JSON-RPC method " ~ $req.method ~ " is not implemented by " ~ $obj.^name,
                data => %( method => $req.method ),
            ).throw;
        }

        my $signature = $method.signature;
        my $params;

        # Only use jrpc request object as a parameter if method accepts it. Multi-methods will never receive the
        # object, only the parameters.
        if $method.candidates[0].multi
           or ( $signature.arity != 2 # 2 because method's arity includes self
                or $signature.count != 2
                or $signature.params[1].type !~~ Cro::RPC::JSON::Request
           )
        {
            $params = $req.params;
        }
        else {
            $params = [ $req ];
        }

        #note "METHOD {$method.name} PARAMS: ", $params;

        do {
            CATCH {
                #note "CAUGHT EXCEPTION ", $_.^name;

                when X::Multi::NoMatch {
                    #note "NO MATCHING METHOD";
                    X::Cro::RPC::JSON::MethodNotFound.new(
                        msg  => "There is no matching variant for multi method '{$req.method}' on {$obj.WHO}",
                        data => %( method => $req.method )
                        ).throw
                }
                when X::Cro::RPC::JSON {
                    $_.rethrow;
                }
                default {
                    #note "INTERNAL FAIL [{$_.WHO}]: ", ~$_, ~$_.backtrace;
                    X::Cro::RPC::JSON::InternalError.new(
                        msg  => ~$_,
                        data => %(
                            exception => .^name,
                            backtrace => ~.backtrace,
                        ),
                        ).throw
                }
            }

            $obj.$method( |$params )
        }
    }

    samewith( &obj-handler );
}

BEGIN {
    multi trait_mod:<is>(Method:D $meth, Bool :$json-rpc) is export {
        Cro::RPC::JSON::Utils::apply-trait( $meth.name, $meth );
    }

    multi trait_mod:<is>( Method:D \meth, Str:D :$json-rpc! ) is export {
        Cro::RPC::JSON::Utils::apply-trait( $json-rpc, meth );
    }
}

=begin pod

=head1 SEE ALSO

L<Cro|https://cro.services>

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
