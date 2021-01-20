use v6.d;
unit class JRPC-WS-Actor;
use Cro::RPC::JSON;

has %!subscriptions;
has $.close-code;
has $.async-close-code;
has Promise:D $.closed .= new;
has Promise:D $.exhausted .= new;

method !subscription(@names, Bool :$unsubscribe --> Hash:D) {
    my %results;
    for @names -> $ns {
        if $unsubscribe {
            %!subscriptions{$ns}:delete;
        }
        else {
            %!subscriptions{$ns} = 0;
        }
        %results{$ns} = "ok";
    }
    return %results;
}

method subscribe(:$event) is json-rpc("rpc.on") {
    self!subscription($event)
}

method unsubscribe(:$event) is json-rpc("rpc.off") {
    self!subscription($event, :unsubscribe)
}

proto method foo(|) is json-rpc {*}

multi method foo(Int:D :$num!) {
    %( multiple => $num * 2 )
}
multi method foo(Str:D :$msg!) {
    "+" ~ $msg ~ "+"
}

method event-emitter(Promise $close?) is json-rpc(:async) {
    supply {
        whenever Supply.interval(.1) {
            for %!subscriptions.keys.sort -> $ns {
                jrpc-notify %(
                    :namespace($ns), :params(++%!subscriptions{$ns}),
                );
            }
        }
        with $close {
            whenever $close -> $req {
                $!async-close-code = (await $req.body).read-uint16(0);
                done;
            }
        }
    }
}

method on-wsclose($code) is json-rpc(:wsclose) {
    $!close-code = $code;
}

method on-close is json-rpc(:close) {
    $!closed.keep
}

method on-last is json-rpc(:last) {
    $!exhausted.keep;
}

