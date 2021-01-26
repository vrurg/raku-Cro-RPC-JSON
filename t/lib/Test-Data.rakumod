use v6.d;
unit module Test-Data;
use Cro::RPC::JSON::Exception;

our @jrpc-requests =
    {
        subtest => "method foo",
        method => "foo",
        params => { a => 2, b => "two" },
        status => 200,
        result => "two and 2",
    },
    {
        subtest => "method by-request",
        method => "by-request",
        params => { a => 2, b => "two" },
        status => 200,
        result => { param-count => 2 },
    },
    {
        subtest => "method bar with a hash",
        method => "bar",
        params => { a => "A!" },
        status => 200,
        result => "single named Str param",
    },
    {
        subtest => "method bar with an array",
        method => "bar",
        params => [ 1, pi, "whatever" ],
        status => 200,
        result => "Int, Num, Str positionals",
    },
    {
        subtest => "method bar, slurpy hash",
        method => "bar",
        params => { :t("Їхав до бабусі один сірий гусик"), :p("π"), :e(e) },
        status => 200,
        result => [
            "slurpy hash:",
            { :t("Їхав до бабусі один сірий гусик"), :p("π"), :e(e) }
        ],
    },
    {
        subtest => "try a non-JSON RPC method",
        method => "non-json",
        status => 200,
        error   => {
            code    => JRPCMethodNotFound,
            message => "JSON-RPC method non-json is not implemented by JRPC-Actor",
            data    => { method => "non-json" },
        },
    },
    {
        subtest => "no method",
        method => "no-method",
        status => 200,
        error   => {
            code    => JRPCMethodNotFound,
            message => "JSON-RPC method no-method is not implemented by JRPC-Actor",
            data    => { method => "no-method" },
        },
    },
    {
        subtest => "something failing",
        method => "fail",
        params => { a => 2, b => "two" },
        status => 200,
        error => { code => JRPCInvalidParams, message => "I always fail" },
    },
    {
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
    },
    {
        subtest => "current protocol",
        method => "protocol",
        status => 200,
        result => -> $p { $p eq $*expected-jrpc-protocol },
    },
    {
        subtest => "access to Cro request",
        method => 'cro-request',
        status => 200,
        result => {
            request => 'Cro::HTTP::Request',
            path => '/api',
            method => -> $m { $m eq $*expected-jrpc-method },
        }
    },
    ;
