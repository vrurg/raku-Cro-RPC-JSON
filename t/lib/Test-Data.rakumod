use v6.d;
unit module Test-Data;
use Cro::RPC::JSON::Exception;

our @jrpc-requests =
    %(
        subtest => "method foo",
        method => "foo",
        params => %( a => 2, b => "two" ),
        status => 200,
        result => "two and 2",
    ),
    %(
        subtest => "method by-request",
        method => "by-request",
        params => %( a => 2, b => "two" ),
        status => 200,
        result => %( param-count => 2 ),
    ),
    %(
        subtest => "method bar with a hash",
        method => "bar",
        params => %( a => "A!" ),
        status => 200,
        result => "single named Str param",
    ),
    %(
        subtest => "method bar with an array",
        method => "bar",
        params => [ 1, pi, "whatever" ],
        status => 200,
        result => "Int, Num, Str positionals",
    ),
    %(
        subtest => "method bar, slurpy hash",
        method => "bar",
        params => %( :t("Їхав до бабусі один сірий гусик"), :p("π"), :e(e) ),
        status => 200,
        result => [
            "slurpy hash:",
            %( :t("Їхав до бабусі один сірий гусик"), :p("π"), :e(e) )
        ],
    ),
    %(
        subtest => "undefined params",
        method  => "paramless",
        params  => Any,
        status  => 200,
        result  => "a method with no parameters",
    ),
    %(
        subtest => "Cro request",
        method  => "get-cro-req",
        params  => Any,
        status  => 200,
        result  => rx/^ 'Cro::HTTP::Request|' \d+ /,
    ),
    %(
        subtest => "Cro::RPC::JSON request",
        method  => "get-jrpc-req",
        params  => Any,
        status  => 200,
        result  => rx/^ 'Cro::RPC::JSON::Request|' \d+ /,
    ),
    %(
        subtest => 'marshaling an object',
        method  => 'return-obj',
        params  => Any,
        status  => 200,
        result  => %(
            count => 42,
            name => 'The Answer',
        ),
    ),
    %(
        subtest => 'unmarshaling into an object',
        method  => 'accept-obj',
        params  => %( :name('The Question'), :count(13) ),
        status  => 200,
        result  => "JRPC-Actor::IntraFoo.new(name => \"The Question\", count => 13)",
    ),
    %(
        subtest => 'unmarshaling into an array of objects',
        method  => 'accept-obj-array',
        params  => [[
            %( :name('question 1'), :count(13) ),
            %( :name('question 2'), :count(42) ),
            %( :name('question 3'), :count(0) ),
        ],],
        status  => 200,
        result  => "Array[JRPC-Actor::IntraFoo].new(JRPC-Actor::IntraFoo.new(name => \"question 1\", count => 13), JRPC-Actor::IntraFoo.new(name => \"question 2\", count => 42), JRPC-Actor::IntraFoo.new(name => \"question 3\", count => 0))",
    ),
    %(
        subtest => 'unmarshaling into a hash of objects',
        method  => 'accept-obj-hash',
        params  => %(
            q1 => %( :name( 'question 1' ), :count( 13 ) ),
            q2 => %( :name( 'question 2' ), :count( 42 ) ),
            q3 => %( :name( 'question 3' ), :count( 0 ) ),
        ),
        status  => 200,
        result  => "Hash[JRPC-Actor::IntraFoo] = \{ q1 => JRPC-Actor::IntraFoo.new(name => \"question 1\", count => 13), q2 => JRPC-Actor::IntraFoo.new(name => \"question 2\", count => 42), q3 => JRPC-Actor::IntraFoo.new(name => \"question 3\", count => 0) }",
    ),
    %(
        subtest => 'multi-param unmarshalling',
        method  => 'accept-obj-params',
        params  => [
            [
                %( :name('question 1'), :count(13) ),
                %( :name('question 2'), :count(42) ),
                %( :name('question 3'), :count(0) ),
            ],
            %(
                :!flag,
                map => %( :1st ),
            ),
            %(
                :flag,
                map => %( :2nd ),
            ),
            "plain",
            <A B C>,
        ],
        status  => 200,
        result  => q:to/TEST-RETURN/.chomp,
Array[JRPC-Actor::IntraFoo].new(JRPC-Actor::IntraFoo.new(name => "question 1", count => 13), JRPC-Actor::IntraFoo.new(name => "question 2", count => 42), JRPC-Actor::IntraFoo.new(name => "question 3", count => 0))
JRPC-Actor::IntraBar.new(flag => Bool::False, map => {:st(1)})
[{:flag(Bool::True), :map(${:nd(2)})}, "plain", ["A", "B", "C"]]
TEST-RETURN
    ),
    %(
        subtest => 'unmarshaling with multi-dispatch method, Str candidate ',
        method  => 'accept-obj-multi',
        params  => [ %( :name('The Question'), :count(13) ), "one" ],
        status  => 200,
        result  => "Str candidate one",
    ),
    %(
        subtest => 'unmarshaling with multi-dispatch method, Int candidate ',
        method  => 'accept-obj-multi',
        params  => [ %( :name('The Question'), :count(13) ), 42 ],
        status  => 200,
        result  => "Int candidate 42",
    ),
    %(
        subtest => 'unmarshaling with multi-dispatch method, Bool candidate ',
        method  => 'accept-obj-multi',
        params  => [ %( :name('The Question'), :count(13) ), False ],
        status  => 200,
        result  => "Bool candidate False",
    ),
    %(
        subtest => 'unmarshaling with multi-dispatch method, no candidate ',
        method  => 'accept-obj-multi',
        params  => [ %( :name('The Question'), :count(13) ), 42.13 ],
        status  => 200,
        error   => %(
            code => -32601,
            message => /:s There is no matching variant for multi method "'accept-obj-multi'" on /,
            data => %(
                method => 'accept-obj-multi',
            ),
        ),
    ),
    %(
        subtest => "try a non-JSON RPC method",
        method => "non-json",
        status => 200,
        error   => {
            code    => JRPCMethodNotFound,
            message => /^ "JSON-RPC method non-json is not implemented by " \S+ $/,
            data    => %( method => "non-json" ),
        },
    ),
    %(
        subtest => "no method",
        method => "no-method",
        status => 200,
        error   => {
            code    => JRPCMethodNotFound,
            message => /^ "JSON-RPC method no-method is not implemented by " \S+ $/,
            data    => { method => "no-method" },
        },
    ),
    %(
        subtest => "something failing",
        method => "fail",
        params => { a => 2, b => "two" },
        status => 200,
        error => { code => JRPCInvalidParams, message => "I always fail" },
    ),
    %(
        subtest => "a mortal one",
        method => "mortal",
        params => { a => 2, b => "two" },
        status => 200,
        error   => {
            code    => JRPCInternalError,
            message => "Simulate... well... something",
            data    => {
                exception => 'X::AdHoc',
                backtrace => Str:D,
            },
        }
    ),
    %(
        subtest => "current protocol",
        method => "protocol",
        status => 200,
        result => -> $p { $p eq $*expected-jrpc-protocol },
    ),
    %(
        subtest => "access to Cro request",
        method => 'cro-request',
        status => 200,
        result => {
            request => 'Cro::HTTP::Request',
            path => '/api',
            method => -> $m { $m eq $*expected-jrpc-method },
        }
    ),
    ;
