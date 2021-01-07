#!/usr/bin/env raku

use lib <lib>;
use META6;
use Cro::RPC::JSON;

my $m = META6.new(
    name           => 'Cro::RPC::JSON',
    description    => 'Cro JSON-RPC implementation',
    version        => Cro::RPC::JSON.^ver,
    raku-version   => Version.new('6.d'),
    depends        => <
        Cro::HTTP
        JSON::Fast
    >,
    test-depends   => <Test Test::META Test::When Cro::HTTP::Test>,
    #build-depends  => <META6 Pod::To::Markdown>,
    tags           => <Cro JSON-RPC>,
    authors        => ['Vadim Belman <vrurg@cpan.org>'],
    auth           => 'github:vrurg',
    source-url     => 'git://github.com/vrurg/raku-Cro-RPC-JSON.git',
    support        => META6::Support.new(
        source          => 'https://github.com/vrurg/raku-Cro-RPC-JSON.git',
    ),
    provides => {
        'Cro::RPC::JSON' => 'lib/Cro/RPC/JSON.rakumod',
        'Cro::RPC::JSON::BatchRequest' => 'lib/Cro/RPC/JSON/BatchRequest.rakumod',
        'Cro::RPC::JSON::BatchResponse' => 'lib/Cro/RPC/JSON/BatchResponse.rakumod',
        'Cro::RPC::JSON::Exception' => 'lib/Cro/RPC/JSON/Exception.rakumod',
        'Cro::RPC::JSON::Handler' => 'lib/Cro/RPC/JSON/Handler.rakumod',
        'Cro::RPC::JSON::Message' => 'lib/Cro/RPC/JSON/Message.rakumod',
        'Cro::RPC::JSON::Metamodel::ClassHOW' => 'lib/Cro/RPC/JSON/Metamodel/ClassHOW.rakumod',
        'Cro::RPC::JSON::Metamodel::MethodContainer' => 'lib/Cro/RPC/JSON/Metamodel/MethodContainer.rakumod',
        'Cro::RPC::JSON::Metamodel::RoleHOW' => 'lib/Cro/RPC/JSON/Metamodel/RoleHOW.rakumod',
        'Cro::RPC::JSON::MethodResponse' => 'lib/Cro/RPC/JSON/MethodResponse.rakumod',
        'Cro::RPC::JSON::Request' => 'lib/Cro/RPC/JSON/Request.rakumod',
        'Cro::RPC::JSON::RequestParser' => 'lib/Cro/RPC/JSON/RequestParser.rakumod',
        'Cro::RPC::JSON::Response' => 'lib/Cro/RPC/JSON/Response.rakumod',
        'Cro::RPC::JSON::ResponseSerializer' => 'lib/Cro/RPC/JSON/ResponseSerializer.rakumod',
    },
    license        => 'Artistic-2.0',
    :!production,
);

print $m.to-json;

#my $m = META6.new(file => './META6.json');
#$m<version description> = v0.0.2, 'Work with Perl 6 META files even better';
#spurt('./META6.json', $m.to-json);

