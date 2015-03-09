#
# Varnish VCL file for Ghost blogging platform.
# http://ghost.org/
#
# Written for Ghost v0.3.0.
#
# This is a low-hanging-fruit type of VCL. TTL of objects are overridden to 2
# minutes, and everything below /ghost/ is pass()-ed so the user sessions
# work.
#
# Author: Lasse Karstensen <lasse.karstensen@gmail.com>, September 2013.


backend default {
    .host = "node1";
#    .port = "2368";
    .port = "8081";
}


sub vcl_recv {
    # If the client uses shift-F5, get (and cache) a fresh copy. Nice for
    # systems without content invalidation. Big sites will want to disable
    # this.
    if (req.http.cache-control ~ "no-cache") {
        set req.hash_always_miss = true;
    }

    set req.http.x-pass = "false";
    # TODO: I haven't seen any urls for logging access. When the
    # analytics parts of ghost are done, this needs to be added in the
    # exception list below.
    if (req.url ~ "^/(api|signout)") {
        set req.http.x-pass = "true";
    } elseif (req.url ~ "^/ghost" && (req.url !~ "^/ghost/(img|css|fonts)")) {
        set req.http.x-pass = "true";
    }

    if (req.http.x-pass == "true") {
        return(pass);
    }
    unset req.http.cookie;
}

sub vcl_fetch {
    # Only modify cookies/ttl outside of the management interface.
    if (req.http.x-pass != "true") {
        unset beresp.http.set-cookie;
        if (beresp.status < 500 && beresp.ttl == 0s) {
            set beresp.ttl = 2m;
        }
    }
}


