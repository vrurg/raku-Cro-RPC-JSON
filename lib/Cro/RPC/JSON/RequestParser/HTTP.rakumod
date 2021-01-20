use v6.d;
unit class Cro::RPC::JSON::RequestParser::HTTP:api<2>;

use Cro::Transform;
use Cro::RPC::JSON::Exception;
use Cro::RPC::JSON::RequestParser::BodyStr;

also does Cro::Transform;
also does Cro::RPC::JSON::RequestParser::BodyStr;

method consumes { Cro::HTTP::Request }
method produces { Cro::RPC::JSON::Message }

method transformer (Supply:D $in) {
#    note "--> RequestParser got \$in: ", $in.WHO;
    supply {
        whenever $in -> $request {
            unless $request.method.fc ~~ 'post'.fc {
                # Must produce HTTP 500
                die "JSON-RPC is only supported for POST method";
            }
            my $content-type = $request.content-type;

            unless $content-type.type-and-subtype ~~ 'application/json' {
                X::Cro::RPC::JSON::MediaType.new(:$content-type).throw;
            }

            emit self.body-to-request: await $request.body-text;
        }
    }
}

# Copyright (c) 2018-2021, Vadim Belman <vrurg@cpan.org>
