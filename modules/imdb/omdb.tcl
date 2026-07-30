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

proc ::dZSbot::Modules::IMDb::OMDb::BuildUrl {endpoint apiKey query {type ""} {year ""}} {

    if {[regexp -nocase {^tt[0-9]+$} $query]} {
        set args [list apikey $apiKey i $query plot short r json]
    } else {
        set args [list apikey $apiKey t $query plot short r json]
    }
    if {$type ne ""} {
        lappend args type $type
    }
    if {$year ne ""} {
        lappend args y $year
    }
    set params [::http::formatQuery {*}$args]

    return "${endpoint}?$params"
}

proc ::dZSbot::Modules::IMDb::OMDb::BuildSearchUrl {endpoint apiKey query {type ""} {year ""}} {

    set args [list apikey $apiKey s $query r json]
    if {$type ne ""} {
        lappend args type $type
    }
    if {$year ne ""} {
        lappend args y $year
    }

    return "${endpoint}?[::http::formatQuery {*}$args]"
}

proc ::dZSbot::Modules::IMDb::OMDb::Fetch {query {type ""} {year ""}} {

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

    set fetched [Request [BuildUrl $endpoint $apiKey $query $type $year] $timeout]
    if {![dict get $fetched ok]} {
        return $fetched
    }

    if {[regexp -nocase {^tt[0-9]+$} $query] ||
        ![::dZSbot::Config::Get omdb.search_fallback 1] ||
        ![ShouldSearchFallback [dict get $fetched data]]} {
        return $fetched
    }

    set searchYears [list $year]
    if {$year ne ""} {
        lappend searchYears ""
    }

    foreach searchYear $searchYears {
        foreach searchQuery [SearchVariants $query] {
            set searched [Request [BuildSearchUrl \
                $endpoint $apiKey $searchQuery $type $searchYear] $timeout]
            if {![dict get $searched ok]} {
                return $searched
            }

            set imdbId [SelectSearchResult \
                [dict get $searched data] $query $type $year]
            if {$imdbId ne ""} {
                return [Request [BuildUrl $endpoint $apiKey $imdbId] $timeout]
            }
        }
    }

    return $fetched
}

proc ::dZSbot::Modules::IMDb::OMDb::Request {url timeout} {

    set token ""
    if {[catch {
        set token [::http::geturl $url -timeout $timeout]
        set status [::http::status $token]
        set code [::http::ncode $token]
        set data [::http::data $token]
    } error]} {
        if {$token ne ""} {
            catch {::http::cleanup $token}
        }
        return [dict create ok 0 error $error]
    }

    ::http::cleanup $token

    if {$status ne "ok" || $code < 200 || $code >= 300} {
        return [dict create ok 0 error "HTTP status $status ($code)"]
    }

    return [dict create ok 1 data $data]
}

proc ::dZSbot::Modules::IMDb::OMDb::ShouldSearchFallback {json} {

    return [expr {
        [regexp -nocase {"Response"[ \t\r\n]*:[ \t\r\n]*"False"} $json] &&
        [regexp -nocase {"Error"[ \t\r\n]*:[ \t\r\n]*"[^"]*not found} $json]
    }]
}

proc ::dZSbot::Modules::IMDb::OMDb::NormalizeTitle {title} {

    set normalized [string tolower [string trim $title]]
    regsub -all {[^[:alnum:]]+} $normalized "" normalized
    return $normalized
}

proc ::dZSbot::Modules::IMDb::OMDb::SearchVariants {query} {

    set variants [list $query]
    set words [split $query " "]

    # Scene release names omit apostrophes. Try one possessive restoration at a
    # time, for example "The Devils Mouth" -> "The Devil's Mouth".
    for {set index 0} {$index < [expr {[llength $words] - 1}]} {incr index} {
        set word [lindex $words $index]
        if {![regexp -nocase {^[[:alpha:]]{5,}s$} $word]} {
            continue
        }

        set variantWords $words
        regsub -nocase {s$} $word {'s} possessive
        lset variantWords $index $possessive
        set variant [join $variantWords " "]
        if {[lsearch -exact $variants $variant] < 0} {
            lappend variants $variant
        }
    }

    return $variants
}

proc ::dZSbot::Modules::IMDb::OMDb::SelectSearchResult {json query {type ""} {year ""}} {

    if {[catch {
        package require json
        set data [::json::json2dict $json]
    }]} {
        if {[regexp -nocase {"imdbID"[ \t\r\n]*:[ \t\r\n]*"(tt[0-9]+)"} $json -> imdbId]} {
            return $imdbId
        }
        return ""
    }

    if {![dict exists $data Response] ||
        ![string equal -nocase [dict get $data Response] "True"] ||
        ![dict exists $data Search]} {
        return ""
    }

    set normalizedQuery [NormalizeTitle $query]
    set bestId ""
    set bestScore -100000
    set index 0

    foreach result [dict get $data Search] {
        if {![dict exists $result imdbID]} {
            incr index
            continue
        }

        set score [expr {-$index}]
        set resultTitle [expr {[dict exists $result Title] ? [dict get $result Title] : ""}]
        set resultYear [expr {[dict exists $result Year] ? [dict get $result Year] : ""}]
        set resultType [expr {[dict exists $result Type] ? [dict get $result Type] : ""}]
        set normalizedResult [NormalizeTitle $resultTitle]

        if {$normalizedResult eq $normalizedQuery} {
            incr score 100
        } elseif {[string first $normalizedQuery $normalizedResult] == 0 ||
                  [string first $normalizedResult $normalizedQuery] == 0} {
            incr score 40
        }
        if {$year ne "" && [string first $year $resultYear] == 0} {
            incr score 25
        }
        if {$type ne "" && [string equal -nocase $type $resultType]} {
            incr score 10
        }

        if {$bestId eq "" || $score > $bestScore} {
            set bestId [dict get $result imdbID]
            set bestScore $score
        }
        incr index
    }

    return $bestId
}
