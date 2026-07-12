namespace eval ::dZSbot::Modules::IMDb::OMDb {}

proc ::dZSbot::Modules::IMDb::OMDb::EnsureHttp {endpoint} {

    if {[catch {package require http} error]} {
        return "Tcl http package is not available: $error"
    }

    if {[string match -nocase "https://*" $endpoint]} {
        if {[catch {::dZSbot::Packages::EnsureHttps} error]} {
            return "Tcl tls package is required for HTTPS OMDb lookups: $error"
        }
    }

    return ""
}

proc ::dZSbot::Modules::IMDb::OMDb::BuildUrl {endpoint apiKey query {type ""}} {

    if {[regexp -nocase {^tt[0-9]+$} $query]} {
        set args [list apikey $apiKey i $query plot short r json]
    } else {
        set args [list apikey $apiKey t $query plot short r json]
    }
    if {$type ne ""} {
        lappend args type $type
    }
    set params [::http::formatQuery {*}$args]

    return "${endpoint}?$params"
}

proc ::dZSbot::Modules::IMDb::OMDb::Fetch {query {type ""}} {

    set apiKey [::dZSbot::Config::Get omdb.api_key ""]
    set endpoint [string trimright [::dZSbot::Config::Get omdb.endpoint "https://www.omdbapi.com/"] "?"]
    set timeout [::dZSbot::Config::Get omdb.timeout_ms 15000]

    if {$apiKey eq ""} {
        return [dict create ok 0 error "OMDb API key is missing. Set omdb.api_key in config/dzsbot.conf."]
    }

    set packageError [EnsureHttp $endpoint]
    if {$packageError ne ""} {
        return [dict create ok 0 error $packageError]
    }

    set url [BuildUrl $endpoint $apiKey $query $type]

    if {[catch {
        set token [::http::geturl $url -timeout $timeout]
        set status [::http::status $token]
        set code [::http::ncode $token]
        set data [::http::data $token]
        ::http::cleanup $token
    } error]} {
        return [dict create ok 0 error $error]
    }

    if {$status ne "ok" || $code < 200 || $code >= 300} {
        return [dict create ok 0 error "HTTP status $status ($code)"]
    }

    return [dict create ok 1 data $data]
}
