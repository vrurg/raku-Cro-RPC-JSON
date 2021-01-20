unit role Cro::RPC::JSON::Method:api<2>;
use Cro::RPC::JSON::Exception;

has Str $.json-rpc-name;

method set-json-rpc-name(Str:D $jrpc-name --> Nil) {
    with $!json-rpc-name {
        X::Cro::RPC::JSON::InternalError.new(
            :msg("Redeclarion of method '"
                 ~ $.name
                 ~ "' as JSON-RPC '"
                 ~ $jrpc-name
                 ~ "'; previously named as '"
                 ~ $_ ~ "'"
            )).throw
        unless $_ eq $jrpc-name;
    }
    $!json-rpc-name = $jrpc-name;
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
