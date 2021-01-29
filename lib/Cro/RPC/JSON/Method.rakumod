unit role Cro::RPC::JSON::Method:api<2>;
use Cro::RPC::JSON::Exception;

has Str $.json-rpc-name;
# An object the user session code can use to authorize a method call. For example, it can be a privilege level of some
# kind.
has Mu $.json-rpc-auth is rw;

# List of adhocs
has Bool %!adhocs;

method set-json-rpc-name( Str:D $jrpc-name --> Nil ) {
    with $!json-rpc-name {
        X::Cro::RPC::JSON::InternalError.new(
            :msg( "Redeclarion of method '"
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

method mark-as-jrpc-adhoc(Str:D $adhoc) { %!adhocs{$adhoc} = True }
method json-rpc-adhocs { %!adhocs.keys }

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
