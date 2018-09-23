#!/usr/bin/env perl6

use lib <lib>;
use META6;
use Cro::RPC::JSON;

my $m = META6.new(
    name           => 'Cro::RPC::JSON',
    description    => 'Cro JSON-RPC implementation',
    version        => Cro::RPC::JSON::VER.^ver,
    perl-version   => Version.new('6.*'),
    #depends        => <JSON::Class>,
    test-depends   => <Test Test::META Test::When Cro::HTTP::Test>,
    build-depends  => <META6 p6doc Pod::To::Markdown>,
    tags           => <Cro JSON-RPC>,
    authors        => ['Vadim Belman <vrurg@cpan.org>'],
    auth           => 'github:vrurg',
    #source-url     => 'git://github.com/vrurg/Perl6-AttrX-Mooish.git',
    #support        => META6::Support.new(
    #    source          => 'git://github.com/vrurg/Perl6-AttrX-Mooish.git',
    #),
    provides => {
        'Cro::RPC::JSON' => 'lib/Cro/RPC/JSON',
    },
    license        => 'Artistic-2.0',
    production     => False,
);

print $m.to-json;

#my $m = META6.new(file => './META6.json');
#$m<version description> = v0.0.2, 'Work with Perl 6 META files even better';
#spurt('./META6.json', $m.to-json);

