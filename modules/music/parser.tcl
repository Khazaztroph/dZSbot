namespace eval ::dZSbot::Modules::Music::Parser {}

proc ::dZSbot::Modules::Music::Parser::NormalizeQuery {text} {

    return [string trim [regsub -all {[ \t]+} $text " "]]
}

proc ::dZSbot::Modules::Music::Parser::GuessFormat {text} {

    set lowered [string tolower $text]

    if {[string match "*.flac*" $lowered] || [string match "* flac*" $lowered]} {
        return flac
    }

    if {[string match "*.mp3*" $lowered] || [string match "* mp3*" $lowered]} {
        return mp3
    }

    return music
}

proc ::dZSbot::Modules::Music::Parser::JsonGet {json key {default ""}} {

    set pattern [format {"%s"[ \t\r\n]*:[ \t\r\n]*"((?:\\.|[^"\\])*)"} $key]

    if {[regexp $pattern $json -> value]} {
        return [string map [list "\\\"" "\"" "\\/" "/" "\\n" "\n" "\\r" "\r" "\\t" "\t" "\\\\" "\\"] $value]
    }

    return $default
}

proc ::dZSbot::Modules::Music::Parser::JsonArrayValues {json key} {

    set pattern [format {"%s"[ \t\r\n]*:[ \t\r\n]*\[([^\]]*)\]} $key]

    if {![regexp $pattern $json -> raw]} {
        return {}
    }

    set values {}
    foreach match [regexp -all -inline {"((?:\\.|[^"\\])*)"} $raw] {
        if {[string index $match 0] eq "\""} {
            lappend values [string map [list "\\\"" "\"" "\\/" "/" "\\n" "\n" "\\r" "\r" "\\t" "\t" "\\\\" "\\"] [string range $match 1 end-1]]
        }
    }

    return $values
}

proc ::dZSbot::Modules::Music::Parser::FirstResultObject {json} {

    set pos [string first "\"results\"" $json]
    if {$pos < 0} {
        return ""
    }

    set start [string first "\{" $json $pos]
    if {$start < 0} {
        return ""
    }

    set depth 0
    set inString 0
    set escaped 0

    for {set i $start} {$i < [string length $json]} {incr i} {
        set char [string index $json $i]

        if {$escaped} {
            set escaped 0
            continue
        }
        if {$char eq "\\"} {
            set escaped 1
            continue
        }
        if {$char eq "\""} {
            set inString [expr {!$inString}]
            continue
        }
        if {$inString} {
            continue
        }
        if {$char eq "\{"} {
            incr depth
        } elseif {$char eq "\}"} {
            incr depth -1
            if {$depth == 0} {
                return [string range $json $start $i]
            }
        }
    }

    return ""
}

proc ::dZSbot::Modules::Music::Parser::ParseDiscogsSearch {json} {

    set first [FirstResultObject $json]
    if {$first eq ""} {
        return [dict create ok 0 error "no Discogs results found"]
    }

    set release [dict create \
        title [JsonGet $first title "Unknown"] \
        year [JsonGet $first year "N/A"] \
        country [JsonGet $first country "N/A"] \
        catno [JsonGet $first catno "N/A"] \
        uri [JsonGet $first uri ""] \
        resource_url [JsonGet $first resource_url ""] \
        formats [JsonArrayValues $first format] \
        labels [JsonArrayValues $first label] \
        genres [JsonArrayValues $first genre] \
        styles [JsonArrayValues $first style]]

    return [dict create ok 1 release $release]
}

proc ::dZSbot::Modules::Music::Parser::CleanReleaseName {release} {

    set name [file rootname $release]
    set name [regsub -all {[\._]+} $name " "]
    set name [regsub -all -nocase {\m(720p|1080p|2160p|flac|mp3|m4a|aac|ogg|opus|web|cd|vinyl|limited|proper|repack|internal|scene)\M} $name " "]
    set name [regsub -all -nocase {\m(19[0-9][0-9]|20[0-9][0-9])\M} $name " "]
    regsub -all {[ ]+} [string trim $name] " " name

    return $name
}
