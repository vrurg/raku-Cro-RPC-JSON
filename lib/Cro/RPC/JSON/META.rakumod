use v6.d;
unit module Cro::RPC::JSON::META;
use META6;
use Cro::RPC::JSON;

our sub META6 {
    api            => Cro::RPC::JSON.^api,
    name           => 'Cro::RPC::JSON',
    description    => 'JSON-RPC 2.0 framework built on top of Cro',
    version        => Cro::RPC::JSON.^ver,
    raku-version   => Version.new('6.d'),
    depends        => <
        Cro::HTTP
        JSON::Fast
        JSON::Marshal
        Cro::HTTP::Router
        Cro::HTTP::Router::WebSocket
    >,
    test-depends   => <Test Test::META Test::When Cro::HTTP::Test>,
    tags           => <Cro JSON-RPC HTTP WEB JSON>,
    authors        => ['Vadim Belman <vrurg@lflat.org>'],
    auth           => 'zef:vrurg',
    source-url     => 'https://github.com/vrurg/raku-Cro-RPC-JSON.git',
    license        => 'Artistic-2.0',
    support        => META6::Support.new(
        source          => 'https://github.com/vrurg/raku-Cro-RPC-JSON.git',
        bugtracker      => 'https://github.com/vrurg/raku-Cro-RPC-JSON/issues',
        ),
    provides => {
        'Cro::RPC::JSON'                                => 'lib/Cro/RPC/JSON.rakumod',
        'Cro::RPC::JSON::Auth'                          => 'lib/Cro/RPC/JSON/Auth.rakumod',
        'Cro::RPC::JSON::BatchRequest'                  => 'lib/Cro/RPC/JSON/BatchRequest.rakumod',
        'Cro::RPC::JSON::BatchResponse'                 => 'lib/Cro/RPC/JSON/BatchResponse.rakumod',
        'Cro::RPC::JSON::Exception'                     => 'lib/Cro/RPC/JSON/Exception.rakumod',
        'Cro::RPC::JSON::Handler'                       => 'lib/Cro/RPC/JSON/Handler.rakumod',
        'Cro::RPC::JSON::META'                          => 'lib/Cro/RPC/JSON/META.rakumod',
        'Cro::RPC::JSON::Message'                       => 'lib/Cro/RPC/JSON/Message.rakumod',
        'Cro::RPC::JSON::Metamodel::ClassHOW'           => 'lib/Cro/RPC/JSON/Metamodel/ClassHOW.rakumod',
        'Cro::RPC::JSON::Metamodel::ConcreteRoleHOW'    => 'lib/Cro/RPC/JSON/Metamodel/ConcreteRoleHOW.rakumod',
        'Cro::RPC::JSON::Metamodel::MethodContainer'    => 'lib/Cro/RPC/JSON/Metamodel/MethodContainer.rakumod',
        'Cro::RPC::JSON::Metamodel::ParametricRoleHOW'  => 'lib/Cro/RPC/JSON/Metamodel/ParametricRoleHOW.rakumod',
        'Cro::RPC::JSON::Method'                        => 'lib/Cro/RPC/JSON/Method.rakumod',
        'Cro::RPC::JSON::MethodResponse'                => 'lib/Cro/RPC/JSON/MethodResponse.rakumod',
        'Cro::RPC::JSON::Notification'                  => 'lib/Cro/RPC/JSON/Notification.rakumod',
        'Cro::RPC::JSON::Request'                       => 'lib/Cro/RPC/JSON/Request.rakumod',
        'Cro::RPC::JSON::RequestParser'                 => 'lib/Cro/RPC/JSON/RequestParser.rakumod',
        'Cro::RPC::JSON::RequestParser::BodyStr'        => 'lib/Cro/RPC/JSON/RequestParser/BodyStr.rakumod',
        'Cro::RPC::JSON::RequestParser::HTTP'           => 'lib/Cro/RPC/JSON/RequestParser/HTTP.rakumod',
        'Cro::RPC::JSON::RequestParser::WebSocket'      => 'lib/Cro/RPC/JSON/RequestParser/WebSocket.rakumod',
        'Cro::RPC::JSON::Requestish'                    => 'lib/Cro/RPC/JSON/Requestish.rakumod',
        'Cro::RPC::JSON::Response'                      => 'lib/Cro/RPC/JSON/Response.rakumod',
        'Cro::RPC::JSON::ResponseSerializer'            => 'lib/Cro/RPC/JSON/ResponseSerializer.rakumod',
        'Cro::RPC::JSON::ResponseSerializer::HTTP'      => 'lib/Cro/RPC/JSON/ResponseSerializer/HTTP.rakumod',
        'Cro::RPC::JSON::ResponseSerializer::WebSocket' => 'lib/Cro/RPC/JSON/ResponseSerializer/WebSocket.rakumod',
        'Cro::RPC::JSON::Transform'                     => 'lib/Cro/RPC/JSON/Transform.rakumod',
        'Cro::RPC::JSON::Unmarshal'                     => 'lib/Cro/RPC/JSON/Unmarshal.rakumod',
        'Cro::RPC::JSON::Utils'                         => 'lib/Cro/RPC/JSON/Utils.rakumod',
    },
    :!production,
}
