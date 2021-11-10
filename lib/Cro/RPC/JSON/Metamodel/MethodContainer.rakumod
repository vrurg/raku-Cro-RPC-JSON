use v6.d;
unit role Cro::RPC::JSON::Metamodel::MethodContainer:api<2>;
use nqp;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Method;
use Cro::RPC::JSON::Constants;

has %!jrpc-methods;
has $!adhoc-methods;
# This would serve as class' default auth object used if a method doesn't have it's own set.
has $.jrpc-auth is rw;
has $!parent-jrpc-actors;

method incorporate_multi_candidates(Mu \typeobj) {
    callsame();
    # Fixup protos with JSON-RPC candidates
    for self.methods(typeobj, :local) -> &meth {
        if &meth.is_dispatcher {
            CANDIDATE:
            for &meth.candidates -> &cand {
                if &cand ~~ Cro::RPC::JSON::Method {
                    &meth does Cro::RPC::JSON::Method unless &meth ~~ Cro::RPC::JSON::Method;
                    &meth.set-json-rpc-name($_) with &cand.json-rpc-name;
                    last CANDIDATE;
                }
            }
        }
    }
}

method json-rpc-parent-actors(Mu \type --> List:D) {
    unless $!parent-jrpc-actors {
        $!parent-jrpc-actors := (USE_MRO_CONCRETIZATIONS
            ?? type.^mro(:concretizations)
            !! type.^mro(:roles)
        )[1..*].grep( { .HOW ~~ ::?ROLE } ).List;
    }
    $!parent-jrpc-actors
}

# Add a JSON-RPC export
method json-rpc-add-method(Mu \type, Str:D $jrpc-name, &meth) {
    with %!jrpc-methods{$jrpc-name} {
        # Not using an exception because Rakudo doesn't handle it well here.
        die "Duplicate JSON-RPC name '"
            ~ $jrpc-name
            ~ "' detected on method '"
            ~ &meth.name
            ~ "'; previously used with method '"
            ~ $_ ~ "'"
        unless $_ eq &meth.name;
    }
    else {
        %!jrpc-methods{ $jrpc-name } = &meth.name;
    }
}

# Add an adhoc method
method json-rpc-add-adhoc(Mu \type, Str:D $mod, &meth --> Nil) {
    &meth.mark-as-jrpc-adhoc($mod);
    $!adhoc-methods := nqp::hash() unless nqp::defined($!adhoc-methods);
    my $dmod := nqp::decont($mod);
    my $l := nqp::atkey($!adhoc-methods, $dmod);
    $l := nqp::bindkey($!adhoc-methods, $dmod, nqp::list()) unless nqp::defined($l);
    nqp::push($l, &meth);
}

method json-rpc-adhoc-methods(Mu \type, Str:D $mod, Bool :$local --> List) {
    $!adhoc-methods := nqp::hash() unless nqp::defined($!adhoc-methods);
    nqp::unless(nqp::defined(my $adhocs := nqp::atkey($!adhoc-methods, $mod<>)),
                ($adhocs := nqp::list()));
    unless $local {
        for self.json-rpc-parent-actors(type) -> Mu \typeobj {
            nqp::push($adhocs, $_) for typeobj.^json-rpc-adhoc-methods($mod, :local);
        }
    }
    nqp::hllize($adhocs)
}

# Find a Raku method name by a given JSON-RPC method name
method json-rpc-method-name(Mu \type, Str:D $jrpc-name, Bool :$local --> Str:D) {
    my $meth-name := Nil;
    with %!jrpc-methods{$jrpc-name} {
        $meth-name := $_;
    }
    elsif !$local {
        MRO-SCAN:
        for self.json-rpc-parent-actors(type) -> Mu \typeobj {
            with typeobj.^json-rpc-method-name($jrpc-name, :local) {
                %!jrpc-methods{$jrpc-name} = $meth-name := $_;
                last MRO-SCAN
            }
        }
    }
    $meth-name
}

method json-rpc-find-method(Mu \type, Str $jrpc-name, Bool :$local --> Code) is raw {
    my $meth = self.find_method(
        type,
        self.json-rpc-method-name(type, $jrpc-name, :$local),
        :$local, :no_fallback);
    nqp::defined($meth) && $meth ~~ Cro::RPC::JSON::Method
        ?? $meth
        !! Nil
}

method json-rpc-auth(Mu \type, Bool :$local) {
    return $_ with $!jrpc-auth;
    unless $local {
        for self.json-rpc-parent-actors(type) -> Mu \typeobj {
            return $_ with typeobj.HOW.jrpc-auth;
        }
    }
    Nil
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
