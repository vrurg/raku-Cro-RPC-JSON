unit module Test::JRPC;
use Cro::HTTP::Server;
use Cro::WebSocket::Client;
use Cro::HTTP::Router::WebSocket;
use Cro::HTTP::Router;
use Cro::RPC::JSON:api<2>;
use Test;

class DeepCompareRec {
    has Str:D $.message = "Failed test:";
    has Str:D @.messages;
    has ::?CLASS:D @.subdiags;
    has Bool:D $.success = True;
    has Bool:D $.is-root = True;

    method msg(*@m) {
        @!messages.push: @m.join;
        self
    }

    method compare-msg($got, Mu \expected) {
        @!messages.push: "expected: "
                         ~ expected.raku
                         ~ "\n     got: "
                         ~ $got.raku;
    }

    method failed { $!success = False; self }
    method set-status(Bool:D $status) {
        $!success = False unless $status;
    }

    method subdiag(|c) {
        @!subdiags.push: my $sd = self.new: |c, :!is-root;
        $sd
    }

    method !nest-messages() {
        return () if $!success;
        my @msg = $.message;
        @msg.append: @!messages.join("\n").indent(2) if @!messages;
        @msg.append: @!subdiags.map({$_!nest-messages}).flat.join("\n").indent(2) if @!subdiags;
        @msg
    }

    method gist(--> Str:D) {
        self!nest-messages.join("\n");
    }
    method Str { self.gist }
}

sub is-deep-compare($got, Mu \expected, Str:D $message, |c) is test-assertion is export {
    my $diag = deep-compare $got, expected, :message('Data structure mismatch'), |c;
    ok $diag.success, $message;
    diag $diag.gist unless $diag.success;
}

proto deep-compare($, Mu \expected, |) is export {*}

multi deep-compare($got, Mu \expected, Str:D :$message, |c --> DeepCompareRec:D) {
    my $diag = DeepCompareRec.new: :$message, :!is-root;
    deep-compare($got, expected, :$diag, |c);
    $diag
}

multi deep-compare($got, Mu \expected, DeepCompareRec:D :$diag = DeepCompareRec.new, Bool :$relaxed --> Bool) {
    if $got ~~ Stringy && expected ~~ Regex {
        unless $got ~~ expected {
            $diag.failed.compare-msg: $got, expected;
        }
    }
    elsif $got !~~ Code && expected ~~ Code:D {
        unless expected.($got) {
            $diag.failed.msg: "code check failed for ", $got.raku;
        }
    }
    elsif expected ~~ Junction:D || !expected.defined {
        unless $got ~~ expected {
            $diag.failed.compare-msg: $got, expected;
        }
    }
    else {
        if $got ~~ Hash {
            for $got.keys.sort -> $key {
                if expected{$key}:exists {
                    my $subdiag = $diag.subdiag: :message("Key '" ~ $key ~ "':");
                    $diag.set-status: deep-compare($got{$key}, expected{$key}, :diag($subdiag), :$relaxed);
                }
                elsif !$relaxed {
                    $diag.failed.msg: "got unexpected key '" ~ $key ~ "'\n"
                        ~ ($key ~ " => " ~ $got{$key}.raku).indent(4);
                }
            }
            for expected.keys.sort -> $key {
                $diag.failed.msg: "expected key '" ~ $key ~ "' is missing"
                    unless $got{$key}:exists;
            }
        }
        elsif $got ~~ Array {
            if !$relaxed && $got.elems != expected.elems {
                $diag.failed.compare-msg: $got.elems ~ " array element(s)", expected.elems ~ " array element(s)";
            }
            else {
                my $i = 0;
                while $i < $got.elems & expected.elems {
                    my $message = "At position " ~ $i ~ ":";
                    if !$relaxed && (($got[$i]:exists) ^^ (expected[$i]:exists)) {
                        $diag.failed
                            .subdiag(:$message)
                            .failed
                            .compare-msg: "exists: " ~ $got[$i]:exists, "exists: ", expected[$i]:exists;
                    }
                    else {
                        my $subdiag = $diag.subdiag: :$message;
                        $diag.set-status: deep-compare($got[$i], expected[$i], :diag($subdiag), :$relaxed);
                    }
                    ++$i;
                }
            }
        }
        else {
            unless $got eqv expected {
                $diag.failed.compare-msg: $got, expected;
            }
        }
    }

    if $diag.is-root && !$diag.success {
        diag $diag.gist;
    }
    $diag.success
}

sub next-id is export { $++ }

class ClientServer is export {
    use JRPC-WS-Actor;

    has Int:D $.port is rw = $*CRO-RPC-JSON-PORT // 3005;
    has $.server;
    has $.client;
    has $.connection;
    has Bool:D $.websocket = True;
    has Bool:D $.json = True;
    has Str:D $.url = "http://localhost:$!port/api";
    has Any $!actor is built where *.defined;
    has $!application is built;

    submethod TWEAK {
        CATCH {
            note "New ClientServer: ", .raku;
        }
        $!server //= Cro::HTTP::Server.new(:$!port, application => self.application);
        # XXX How do we know if server start failed???
        $!server.start;

        without $!connection {
            $!client //= ($!websocket
                ?? Cro::WebSocket::Client
                !! Cro::HTTP::Client
            ).new: :$!json;
            my $connection = $!client.connect: $!url;
            await Promise.anyof($connection, Promise.in(5));
            if $connection.status != Kept {
                flunk 'Connection promise is not Kept';
                if $connection.status == Broken {
                    diag $connection.cause;
                }
                bail-out;
            } else {
                $!connection = $connection.result;
            }
        }
    }

    method actor {
        $!actor //= JRPC-WS-Actor.new
    }

    method application {
        $!application //= route {
            get -> 'api' {
                json-rpc :ws, self.actor;
            }
        }
    }
}
