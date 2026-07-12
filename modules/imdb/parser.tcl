namespace eval ::dZSbot::Modules::IMDb::Parser {}

proc ::dZSbot::Modules::IMDb::Parser::JsonToDict {json} {

    if {![catch {package require json}]} {
        return [::json::json2dict $json]
    }

    set result {}
    foreach key {Response Error Title Year Rated Released Runtime Genre Director Writer Actors Plot Language Country Awards Poster Ratings Metascore imdbRating imdbVotes imdbID Type DVD BoxOffice Production Website totalSeasons} {
        dict set result $key [JsonGet $json $key "N/A"]
    }

    return $result
}

proc ::dZSbot::Modules::IMDb::Parser::JsonGet {json key {default ""}} {

    set pattern [format {"%s"[ \t\r\n]*:[ \t\r\n]*"((?:\\.|[^"\\])*)"} $key]

    if {[regexp $pattern $json -> value]} {
        return [string map [list "\\\"" "\"" "\\/" "/" "\\n" "\n" "\\r" "\r" "\\t" "\t" "\\\\" "\\"] $value]
    }

    return $default
}

proc ::dZSbot::Modules::IMDb::Parser::DictGetDefault {data key {default "N/A"}} {

    if {[dict exists $data $key]} {
        set value [dict get $data $key]
        if {$value ne ""} {
            return $value
        }
    }

    return $default
}

proc ::dZSbot::Modules::IMDb::Parser::ParseTitle {json} {

    set data [JsonToDict $json]

    if {[DictGetDefault $data Response "False"] ne "True"} {
        return [dict create ok 0 error [DictGetDefault $data Error "OMDb lookup failed"]]
    }

    set title {}
    foreach key {Title Year Runtime Genre imdbRating imdbVotes Plot Director Actors imdbID Type totalSeasons} {
        dict set title $key [DictGetDefault $data $key]
    }

    set plot [dict get $title Plot]
    if {$plot ne "N/A" && [string length $plot] > 280} {
        dict set title Plot "[string range $plot 0 276]..."
    }

    return [dict create ok 1 title $title]
}

proc ::dZSbot::Modules::IMDb::Parser::ParseMovie {json} {

    set parsed [ParseTitle $json]

    if {![dict get $parsed ok]} {
        return $parsed
    }

    return [dict create ok 1 movie [dict get $parsed title]]
}
