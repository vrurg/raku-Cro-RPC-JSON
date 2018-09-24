
package Cro::RPC::JSON {
    use Cro::HTTP::Router;
    use Cro::RPC::JSON::RequestParser;
    use Cro::RPC::JSON::ResponseSerializer;
    use Cro::RPC::JSON::Handler;
    use Cro::RPC::JSON::Exception;

    module VER:ver<0.0.2>:auth<cpan:VRURG> {}

    proto json-rpc (|) is export { * }

    multi json-rpc ( Code $block ) {
        #note "Creating pipeline with handler ", $block;

        my $request = request;
        my $response = response;

        my $obj = Cro::RPC::JSON::RequestParser.new;

        my Cro::Transform $pipeline = Cro.compose(
            label => "JSON-RPC Handler",
            Cro::RPC::JSON::RequestParser.new,
            Cro::RPC::JSON::Handler.new($block),
            Cro::RPC::JSON::ResponseSerializer.new,
        );
        #note "GEN RESPONSE";
        CATCH {
            #note "PROCESSING EXCEPTION ", $_.WHO, " ", ~$_, $_.backtrace;
            when X::Cro::RPC::JSON {
                #note "STATUS CODE FROM EXCEPTION: ", $_.http-code;
                $response.status = $_.http-code;
            }
            default { 
                #note "CAUGHT EXCEPTION: ", $_.WHO;
                response.status = 500;
                content 'text/plain', '500 ' ~ $_;
            }
        };
        react {
            whenever $pipeline.transformer(
                supply { emit $request }
            ) -> $msg {
                #note "MSG: ", $msg.perl;
                content 'application/json', $msg.json-body;
            }
        }
    }

    multi json-rpc ( $obj ) {
        my sub obj-handler ( $req ) {
            #note "JRPC method {$req.method} on ", $obj.WHO;
            my $method = json-rpc-find-method( $obj, $req.method );
            unless $method {
                my $message = "Method {$obj.WHO}::{$req.method}: " ~ (
                    $obj.^can( $req.method ) ??
                        "doesn't have 'is json-rpc' trait"
                        !!
                        "doesn't exists"
                );
                X::Cro::RPC::JSON::MethodNotFound.new(
                    msg => $message,
                    data => %( method => $req.method ),
                ).throw;
            }

            my $signature = $method.signature;
            my $params;

            # Only use jrpc request object as a parameter if method accepts it. Multi-methods will never receive the
            # object, only the parameters.
            if $method.candidates[0].multi or (
                $signature.arity != 2 # 2 because method's arity includes self
                    or $signature.count != 2
                    or $signature.params[1].type !~~ Cro::RPC::JSON::Request 
            ) {
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
                            data => %( exception => $_.^name ),
                        ).throw
                    }
                }

                $obj."{$method.name}"( |$params )
            }
        }

        samewith( &obj-handler );
    }
}

# ---------------------- TRAIT CODE --------------------------
# Keep it separate here because 'use Cro::HTTP::Route' somehow breaks trait decalaration
role Cro::RPC::JSON::RoleHOW { ... }
role Cro::RPC::JSON::ClassHOW { ... }

role Cro::RPC::JSON::MethodContainer {
    has %!jrpc-methods;

    method json-rpc-add-method ( Mu \type, Str $jrpc-name, &m ) {
        %!jrpc-methods{ $jrpc-name } = &m.name;
    }

    method json-rpc-find-method ( Mu \type, Str $name ) {
        #note "Looking for json method on {type.^name}";
        my $m = %!jrpc-methods{ $name };
        unless $m && type.HOW ~~ Metamodel::ClassHOW {
            #note "TYPE IS CLASS, trying MRO";
            for type.^roles
                    .map( { .^candidates[0] } )
                    .grep( { .HOW ~~ Cro::RPC::JSON::RoleHOW } ) -> $role {
                        #note "Checking role ", $role.^name;
                last if $m = $role.^json-rpc-find-method( $name );
            }
        }
        $m
    }
}

role Cro::RPC::JSON::ClassHOW does Cro::RPC::JSON::MethodContainer {
}

role Cro::RPC::JSON::RoleHOW does Cro::RPC::JSON::MethodContainer {
    method specialize ( Mu \r, Mu:U \obj, |c ) {
        #note "Applying ClassHOW to ", obj.^name;
        obj.HOW does Cro::RPC::JSON::ClassHOW unless obj.HOW ~~ Cro::RPC::JSON::ClassHOW;
        nextsame;
    }
}

sub apply-trait ( Str:D $name, Method:D $m ) {
    my $pkg = $m.package;
    #note "{$m.name} package is {$pkg.^name} // {$pkg.HOW.^name}";
    given $pkg.HOW {
        when Metamodel::ClassHOW {
            $pkg.HOW does Cro::RPC::JSON::ClassHOW unless $pkg.HOW ~~ Cro::RPC::JSON::ClassHOW;
        }
        when Metamodel::ParametricRoleHOW {
            $pkg.HOW does Cro::RPC::JSON::RoleHOW unless $pkg.HOW ~~ Cro::RPC::JSON::RoleHOW;
        }
    }
    $pkg.^json-rpc-add-method( $name, $m );
}

multi trait_mod:<is>( Method:D $m, Bool :$json-rpc ) is export {
    apply-trait( $m.name, $m );
}

multi trait_mod:<is>( Method:D $m, Str :$json-rpc ) is export {
    apply-trait( $json-rpc, $m );
}

# Method looks up for a JSON-RPC method name C<$method> on object's hierarchy including roles.
sub json-rpc-find-method( $obj, Str $method --> Method) is export {
    #note "* MRO:", $obj.^mro;
    for $obj.^mro.grep( { .HOW ~~ Cro::RPC::JSON::ClassHOW } ) -> $class {
        with $class.^json-rpc-find-method( $method ) {
            return $obj.^find_method( $_ );
        }
    }
}

=begin pod
=head1 NAME

C<Cro::RPC::JSON> - convinience shortcut for JSON-RPC 2.0

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

        method fail (|) is json-rpc {
            X::Cro::RPC::JSON::InvalidParams.new( msg => "I always fail" ).throw;
        }

        method mortal (|) is json-rpc {
            die "Simulate... well... something";
        }

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

Sorry, no description yet. Will write it soon.

=head1 AUTHOR

Vadim Belman <vrurg@cpan.org>

=head1 LICENSE

Artistic License 2.0

See the LICENSE file in this distribution.

=end pod

# Copyright (c) 2018, Vadim Belman <vrurg@cpan.org>

