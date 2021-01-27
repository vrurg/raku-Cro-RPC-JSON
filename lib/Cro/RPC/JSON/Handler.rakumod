use v6.d;
unit class Cro::RPC::JSON::Handler:api<2>;

use Cro::Transform;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Message;
use Cro::RPC::JSON::Request;
use Cro::RPC::JSON::Requestish;
use Cro::RPC::JSON::BatchRequest;
use Cro::RPC::JSON::BatchResponse;
use Cro::RPC::JSON::MethodResponse;
use Cro::RPC::JSON::Notification;
use Cro::RPC::JSON::Utils;

also does Cro::Transform;
also does Cro::RPC::JSON::Requestish;

has Str:D $.protocol is required;
has &.code;
has Supply $.async;
#| WebSocket close promise
has Promise $.close;

has Bool $!code-is-async;

multi method new (Code:D $code, |c) { self.new(:$code, |c) }

submethod TWEAK {
    my $sign = &!code.signature;
    $!code-is-async = ($sign.arity > 1) # Two-parameter code expects WebSockets $close
                      || ($sign.params[0].type ~~ Supply) # Or expects a Supply as the first parameter
                      || ($sign.returns ~~ Supply); # Or returns a Supply
}

method consumes { Cro::RPC::JSON::Message }
method produces { Cro::RPC::JSON::Message }

method transformer(Supply:D $in) {
    if $!code-is-async {
        my $out = Supplier.new;
        my @pos = $out.Supply;
        if &!code.signature.count > 1 {
            with $!close {
                @pos.push: $!close;
            }
            elsif &!code.signature.arity > 1 {
                X::Cro::RPC::JSON::ServerError.new(
                    :msg( "Can't provide 'close' argument in a non-WebSocket context" ),
                    :code( JRPCContext ),
                    ).throw;
            }
        }
        my $*CRO-JRPC-PROTOCOL = $!protocol;
        my $*CRO-JRPC-ASYNC = True;
        my $from-user = &!code( |@pos );
        supply {
            whenever $in -> $msg {
                my @reqs;
                if $msg ~~ Cro::RPC::JSON::BatchRequest {
                    @reqs.append: $msg.jrpc-requests;
                }
                else {
                    @reqs.push: $msg;
                }
                for @reqs -> $req {
                    if $req.invalid {
                        $req.respond;
                    }
                    else {
                        $out.emit($req);
                    }
                }
                LAST { $out.done }
            }
            whenever $from-user -> $resp {
                if $resp ~~ Cro::RPC::JSON::MethodResponse
                            | Cro::RPC::JSON::BatchResponse
                            | Cro::RPC::JSON::Notification
                            | Cro::Message
                {
                    emit $resp
                }
                else {
                    X::Cro::RPC::JSON::ServerError.new(
                        :msg("Bad response of type '" ~ $resp.^name ~ "' produced by async code"),
                        :code(JRPCErrGeneral),
                        ).throw;
                }
            }
        };
    }
    else {
        supply {
            whenever $in -> $msg {
                #            note "Handling JSON block ", $msg.perl;
                my $*CRO-JRPC-PROTOCOL = $!protocol;
                my $*CRO-JRPC-ASYNC = False;
                given $msg {
                    when Cro::RPC::JSON::Request {
                        self.handle-request( $_ );
                    }
                    when Cro::RPC::JSON::BatchRequest {
                        for .jrpc-requests -> $req {
                            self.handle-request( $req )
                        }
                    }
                    default {
                        X::Cro::RPC::JSON::ServerError.new(
                            :msg("Cannot handle a request object of type " ~ .^name),
                            :code(JRPCBadReqType),
                            ).throw;
                    }
                }
                $msg.respond;
            }
            with $!async {
                whenever $_ -> $event {
                    if $event ~~ Cro::RPC::JSON::Notification {
                        emit $event
                    }
                    else {
                        emit Cro::RPC::JSON::Notification.new(:json-body($event), :$.request);
                    }
                }
            }
        }
    }
}

method handle-request( Cro::RPC::JSON::Request $req ) {
    my $*CRO-JRPC-RESPONSE =
    my $response = $req.jrpc-response;
    # Make Cro's `request` term work in synchronous code.
    my $*CRO-ROUTER-REQUEST = $req.request;

    my $*CRO-JRPC-REQUEST = $req;

    unless $req.invalid {
        $response.set-result: &!code( $req );
        CATCH {
            when X::Cro::RPC::JSON {
                $response.set-error($_);
            }
        }
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>

