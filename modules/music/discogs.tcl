namespace eval ::dZSbot::Modules::Music::Discogs {}

proc ::dZSbot::Modules::Music::Discogs::EnsureHttp {} {

    if {[catch {package require http} error]} {
        return "Tcl http package is not available: $error"
    }

    if {[catch {::dZSbot::Packages::EnsureHttps} error]} {
        return "Tcl tls package is required for Discogs HTTPS lookups: $error"
    }

    return ""
}

proc ::dZSbot::Modules::Music::Discogs::Fetch {query {format ""}} {

    set request [BuildSearchRequest $query $format]
    if {![dict get $request ok]} {
        return $request
    }

    set url [dict get $request url]
    set headers [dict get $request headers]
    set timeout [::dZSbot::Config::Get discogs.timeout_ms 15000]
    set userAgent [::dZSbot::Config::Get discogs.user_agent "dZSbot/2.0 +https://github.com/dzsbot"]
    set headers [concat [list User-Agent $userAgent] $headers]

    if {[catch {
        set httpToken [::http::geturl $url -timeout $timeout -headers $headers]
        set status [::http::status $httpToken]
        set code [::http::ncode $httpToken]
        set data [::http::data $httpToken]
        ::http::cleanup $httpToken
    } error]} {
        return [dict create ok 0 error $error]
    }

    if {$status ne "ok" || $code < 200 || $code >= 300} {
        return [dict create ok 0 error "HTTP status $status ($code)"]
    }

    return [dict create ok 1 data $data]
}

proc ::dZSbot::Modules::Music::Discogs::BuildSearchRequest {query {format ""}} {

    set packageError [EnsureHttp]
    if {$packageError ne ""} {
        return [dict create ok 0 error $packageError]
    }

    set endpoint [::dZSbot::Config::Get discogs.endpoint "https://api.discogs.com/database/search"]
    set params [SearchParams $query $format]
    set url "${endpoint}?[::http::formatQuery {*}$params]"
    set auth [AuthHeaders $url]

    if {![dict get $auth ok]} {
        return $auth
    }

    return [dict create ok 1 url $url headers [dict get $auth headers]]
}

proc ::dZSbot::Modules::Music::Discogs::SearchParams {query {format ""}} {

    set perPage [::dZSbot::Config::Get discogs.per_page 1]
    set params [list q $query type release per_page $perPage page 1]

    if {$format ne "" && $format ne "music"} {
        lappend params format [string toupper $format]
    }

    if {[string tolower [::dZSbot::Config::Get discogs.auth_mode "token"]] eq "query_token"} {
        set token [::dZSbot::Config::Get discogs.token ""]
        if {$token ne ""} {
            lappend params token $token
        }
    }

    return $params
}

proc ::dZSbot::Modules::Music::Discogs::AuthHeaders {url} {

    set mode [string tolower [::dZSbot::Config::Get discogs.auth_mode "token"]]

    switch -exact -- $mode {
        token -
        token_header {
            set token [::dZSbot::Config::Get discogs.token ""]
            if {$token eq ""} {
                return [AuthError "Discogs token is missing. Set discogs.token in config/modules/music.conf."]
            }
            return [dict create ok 1 headers [list Authorization "Discogs token=$token"]]
        }
        query_token {
            set token [::dZSbot::Config::Get discogs.token ""]
            if {$token eq ""} {
                return [AuthError "Discogs token is missing. Set discogs.token in config/modules/music.conf."]
            }
            return [dict create ok 1 headers {}]
        }
        key_secret {
            set key [::dZSbot::Config::Get discogs.consumer_key ""]
            set secret [::dZSbot::Config::Get discogs.consumer_secret ""]
            if {$key eq "" || $secret eq ""} {
                return [AuthError "Discogs consumer key/secret is missing. Set discogs.consumer_key and discogs.consumer_secret."]
            }
            return [dict create ok 1 headers [list Authorization "Discogs key=$key, secret=$secret"]]
        }
        oauth {
            return [OAuthHeaders $url]
        }
        none {
            return [dict create ok 1 headers {}]
        }
        default {
            return [AuthError "Unsupported Discogs auth mode '$mode'. Use token, query_token, key_secret, oauth, or none."]
        }
    }
}

proc ::dZSbot::Modules::Music::Discogs::OAuthHeaders {url} {

    foreach {key label} {
        discogs.consumer_key consumer_key
        discogs.consumer_secret consumer_secret
        discogs.oauth.access_token access_token
        discogs.oauth.access_token_secret access_token_secret
    } {
        if {[::dZSbot::Config::Get $key ""] eq ""} {
            return [AuthError "Discogs OAuth $label is missing in config/modules/music.conf."]
        }
    }

    if {[catch {package require oauth} error]} {
        return [AuthError "Tcl oauth package is required for Discogs OAuth: $error"]
    }
    ::dZSbot::Packages::EnsureHttps

    ::oauth::config \
        -consumerkey [::dZSbot::Config::Get discogs.consumer_key ""] \
        -consumersecret [::dZSbot::Config::Get discogs.consumer_secret ""] \
        -accesstoken [::dZSbot::Config::Get discogs.oauth.access_token ""] \
        -accesstokensecret [::dZSbot::Config::Get discogs.oauth.access_token_secret ""] \
        -useragent [::dZSbot::Config::Get discogs.user_agent "dZSbot/2.0 +https://github.com/dzsbot"]

    if {[catch {set header [::oauth::header $url]} error]} {
        return [AuthError "Discogs OAuth header failed: $error"]
    }

    return [dict create ok 1 headers $header]
}

proc ::dZSbot::Modules::Music::Discogs::AuthError {message} {

    return [dict create ok 0 error $message]
}
