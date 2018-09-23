use Cro::HTTP::Server;
use Cro::HTTP::Router;
use Cro::RPC::JSON;

sub routes is export {
    route {
        post -> "api" {
            json-rpc -> $json-req {
                #note "This is block handler for json with ", $json-req.perl;
                { a => 1, b => 2 }
            }
        }
    }
}
