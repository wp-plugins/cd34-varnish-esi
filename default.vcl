backend default {
    .host = "127.0.0.1";
    .port = "8080";
}

acl purge {
    "127.0.0.1";
}

sub vcl_recv {
 if (req.request == "BAN") {
   if (!client.ip ~ purge) {
     error 405 "Not allowed.";
   }
   return(lookup);
 }

  if (req.http.Accept-Encoding) {
#revisit this list
    if (req.url ~ "\.(gif|jpg|jpeg|swf|flv|mp3|mp4|pdf|ico|png|gz|tgz|bz2)(\?.*|)$") {
      remove req.http.Accept-Encoding;
    } elsif (req.http.Accept-Encoding ~ "gzip") {
      set req.http.Accept-Encoding = "gzip";
    } elsif (req.http.Accept-Encoding ~ "deflate") {
      set req.http.Accept-Encoding = "deflate";
    } else {
      remove req.http.Accept-Encoding;
    }
  }
  if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    unset req.http.cookie;
    set req.url = regsub(req.url, "\?.*$", "");
  }
  if (req.http.cookie) {
    if (req.http.cookie ~ "(wordpress_|wp-settings-)") {
      return(pass);
    } else {
      unset req.http.cookie;
    }
  }
}

sub vcl_fetch {
# this conditional can probably be left out for most installations
# as it can negatively impact sites without purge support. High
# traffic sites might leave it, but, it will remove the WordPress
# 'bar' at the top and you won't have the post 'edit' functions onscreen.
  if ( (!(req.url ~ "(wp-(login|admin)|login)")) || (req.request == "GET") ) {
    unset beresp.http.set-cookie;
# If you're not running purge support with a plugin, remove
# this line.
    set beresp.ttl = 5m;
  }
  if (req.url ~ "\.(gif|jpg|jpeg|swf|css|js|flv|mp3|mp4|pdf|ico|png)(\?.*|)$") {
    set beresp.ttl = 365d;
  }
}

sub vcl_deliver {
# multi-server webfarm? set a variable here so you can check
# the headers to see which frontend served the request
#   set resp.http.X-Server = "server-01";
   if (obj.hits > 0) {
     set resp.http.X-Cache = "HIT";
   } else {
     set resp.http.X-Cache = "MISS";
   }
}

sub vcl_hit {
  if (req.request == "BAN") {
    set obj.ttl = 0s;
    error 200 "OK";
  }
}

sub vcl_miss {
  if (req.request == "BAN") {
    error 404 "Not cached";
  }
}
