use v6.d;
unit module Basic-JRPC;
use Cro::HTTP::Server;
use Cro::HTTP::Router;
use Cro::RPC::JSON;
use Test;

our sub routes {
    route {
        post -> "api" {
            json-rpc -> $json-req {
                { a => 1, b => 2 }
            }
        }
        get -> "api" {
            # This must die with 'POST only' error
            json-rpc -> $json-req {
                { a => 1, b => 2 }
            }
        }
    }
}

our sub async-routes {
    route {
        post -> "api" {
            json-rpc -> Supply:D $in {
                supply {
                    whenever $in -> $req {
                        $req.respond: { a => 1, b => 2 };
                    }
                }
            }
        }
        get -> "api" {
            # This must die with 'POST only' error
            json-rpc -> $ {
                { a => 1, b => 2 }
            }
        }
    }
}