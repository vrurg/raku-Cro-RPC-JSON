use v6.d;
unit role Cro::RPC::JSON::Metamodel::MethodContainer:api<2>;
use nqp;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::Method;

has %!jrpc-methods;
has %!adhoc-methods;

method json-rpc-add-method ( Mu \type, Str $jrpc-name, &meth ) {
#    note "+ Registering '$jrpc-name' on ", type.^name, " of ", type.HOW.^name,
#        " with ", &meth.raku;
#    note "+ Multi: ", &meth.multi;
#    note "+ Proto: ", &meth.dispatcher.raku;
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

method json-rpc-add-adhoc(Mu \type, Str:D $mod, &meth) {
    (%!adhoc-methods{$mod} //= []).push:  &meth;
}

method adhoc-methods(Mu, Str:D $mod --> List()) { %!adhoc-methods{$mod} // () }
method async-methods(Mu --> List()) { %!adhoc-methods<async><> // () }

method incorporate_multi_candidates(Mu \typeobj) {
    callsame();
#    note "+ FIXUP protos for ", typeobj.^name;
    # Fixup protos with JSON-RPC candidates
    for self.methods(typeobj, :local) -> &meth {
        if &meth.is_dispatcher {
#            note "+  PROTO ", &meth.raku;
            CANDIDATE:
            for &meth.candidates -> &cand {
                if &cand ~~ Cro::RPC::JSON::Method {
#                    note "+  FIXING ", &meth, " from ", &cand.raku;
                    &meth does Cro::RPC::JSON::Method;
                    &meth.set-json-rpc-name(&cand.json-rpc-name);
                    last CANDIDATE;
                }
            }
        }
    }
}

#
method json-rpc-method-name(Mu \type, Str:D $jrpc-name, Bool :$local --> Str:D) {
    my $meth-name := Nil;
    my %mt = %!jrpc-methods;
#    note %mt.WHICH;
#    note "??? CACHED method names on ", type.^name, ": ", %mt.values.join(", ");
    with %!jrpc-methods{$jrpc-name} {
#        note "... JSON-RPC method $jrpc-name found in local cache as ", $_;
        $meth-name := $_;
    }
    else {
#        note "??? Traversing MRO of ", type.^name, " for JSON-RPC method $jrpc-name";
        unless $local {
            MRO-SCAN:
            for type.^mro(:roles)[1..*] -> Mu \typeobj {
                next unless typeobj.HOW ~~ ::?ROLE;
#                note "???   Trying ", typeobj.^name;
                with typeobj.^json-rpc-method-name($jrpc-name, :local) {
#                    note "???     Found $jrpc-name on ", typeobj.^name, " as ", $_;
                    %!jrpc-methods{$jrpc-name} = $meth-name := $_;
                    last MRO-SCAN
                }
            }
        }
    }
    $meth-name
}

method json-rpc-find-method ( Mu \type, Str $name --> Code ) is raw {
#    note "... Looking for json method '$name' on {type.^name}; local cache: ", %!jrpc-methods{$name}.^name;
    my $meth := Nil;
    with %!jrpc-methods{$name} {
        $meth := $_;
    }
    else {
        for type.^mro(:roles)[1..*] -> Mu \typeobj {
#            note "Trying ", typeobj.^name, " of ", typeobj.HOW.^name;
            next unless typeobj.HOW ~~ ::?ROLE;
#            note "... Inspecting ", typeobj.^name, " of ", typeobj.HOW.^name;
            with typeobj.^json-rpc-find-method($name) {
                # Cache the method to speed up next lookup.
#                note "Found ", .raku, " on ", typeobj.^name;
                %!jrpc-methods{$name} := $meth := $_;
            }
        }
    }
    if $meth && $meth.multi {
        # Fixup a cache entry for multi by replacing it with its proto.
        %!jrpc-methods{$name} := $meth := $meth.dispatcher;
    }
    # &meth would still be Nil if nothing found
    $meth
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
