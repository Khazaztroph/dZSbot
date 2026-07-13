namespace eval ::dZSbot::Modules::IMDb {

    variable Version "1.0.0"
    variable Provider "omdb"
    variable RequestTimes {}
}

source [file join $::dZSbot::Root modules imdb cache.tcl]
source [file join $::dZSbot::Root modules imdb omdb.tcl]
source [file join $::dZSbot::Root modules imdb parser.tcl]
source [file join $::dZSbot::Root modules imdb formatter.tcl]
source [file join $::dZSbot::Root modules imdb commands.tcl]

proc ::dZSbot::Modules::IMDb::Initialize {} {

    if {[llength [info commands ::setudef]]} {
        ::setudef flag imdb
    }

    RegisterCommands
    ::dZSbot::Transport::Subscribe site.release ::dZSbot::Modules::IMDb::OnSiteRelease
    ::dZSbot::Transport::Subscribe site.newdir ::dZSbot::Modules::IMDb::OnSiteRelease
}

proc ::dZSbot::Modules::IMDb::ChannelEnabled {chan} {

    set requireFlag [::dZSbot::Config::Get omdb.require_channel_flag 0]

    if {!$requireFlag || $chan eq ""} {
        return 1
    }

    if {![llength [info commands ::channel]]} {
        return 1
    }

    foreach setting [::channel info $chan] {
        if {$setting eq "+imdb"} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::IMDb::FloodAllowed {} {

    variable RequestTimes

    set maxRequests [::dZSbot::Config::Get omdb.max_requests 5]
    set period [::dZSbot::Config::Get omdb.period_seconds 120]
    set now [clock seconds]
    set kept {}

    foreach timestamp $RequestTimes {
        if {[expr {$now - $timestamp}] < $period} {
            lappend kept $timestamp
        }
    }

    set RequestTimes $kept

    if {[llength $RequestTimes] >= $maxRequests} {
        return 0
    }

    lappend RequestTimes $now
    return 1
}

proc ::dZSbot::Modules::IMDb::Lookup {query {type ""} {year ""}} {

    set cacheTime [::dZSbot::Config::Get omdb.cache_seconds 86400]
    set cacheKey $query
    if {$type ne ""} {
        set cacheKey "$type:$query"
    }
    if {$year ne ""} {
        set cacheKey "$cacheKey:$year"
    }
    set cached [::dZSbot::Modules::IMDb::Cache::Get $cacheKey $cacheTime]

    if {$cached eq ""} {
        set fetched [::dZSbot::Modules::IMDb::OMDb::Fetch $query $type $year]

        if {![dict get $fetched ok]} {
            return [dict create ok 0 error [dict get $fetched error]]
        }

        set cached [::dZSbot::Modules::IMDb::Cache::Set $cacheKey [dict get $fetched data]]
    }

    if {[catch {
        set parsed [::dZSbot::Modules::IMDb::Parser::ParseTitle $cached]
    } error]} {
        return [dict create ok 0 error "response parse failed"]
    }

    if {![dict get $parsed ok]} {
        return [dict create ok 0 error [dict get $parsed error]]
    }

    set title [dict get $parsed title]
    return [dict create ok 1 title $title lines [::dZSbot::Modules::IMDb::Formatter::MovieLines $title]]
}

proc ::dZSbot::Modules::IMDb::OnSiteRelease {event payload} {

    if {![::dZSbot::Config::Get imdb.announce.enabled 1]} {
        return
    }

    set release [ReleaseFromPayload $payload]
    set section [string toupper [DictGet $payload section ""]]

    if {$release eq "" || ![ShouldLookupSection $section]} {
        return
    }

    set parsedRelease [ParseReleaseName $release]
    set query [dict get $parsedRelease title]
    if {$query eq ""} {
        return
    }

    set result [Lookup $query "" [dict get $parsedRelease year]]
    set staffChan [::dZSbot::Config::Get imdb.announce.staff_channel "#staff"]

    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply "" $staffChan "IMDb lookup failed for $release: [dict get $result error]"
        return
    }

    set preChan [::dZSbot::Config::Get imdb.announce.pre_channel "#pre"]
    set title [dict get $result title]

    ::dZSbot::Commands::Reply "" $preChan [::dZSbot::Modules::IMDb::Formatter::PublicLine $title $release]
    ::dZSbot::Commands::Reply "" $staffChan "IMDb details for $release:"

    foreach line [dict get $result lines] {
        ::dZSbot::Commands::Reply "" $staffChan $line
    }
}

proc ::dZSbot::Modules::IMDb::ReleaseFromPayload {payload} {

    foreach key {release relname dirname path} {
        set value [DictGet $payload $key ""]
        if {$value ne ""} {
            return [file tail $value]
        }
    }

    return ""
}

proc ::dZSbot::Modules::IMDb::ShouldLookupSection {section} {

    if {$section eq ""} {
        return 1
    }

    set sections [::dZSbot::Config::Get imdb.announce.sections {MOVIES TV}]
    foreach allowed $sections {
        if {[string equal -nocase $allowed $section]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::IMDb::CleanReleaseName {release} {

    return [dict get [ParseReleaseName $release] title]
}

proc ::dZSbot::Modules::IMDb::ParseReleaseName {release} {

    set name [file tail $release]

    # Only remove actual media extensions. "file rootname" also treats the last
    # scene-name component (for example .x264-GROUP) as an extension.
    regsub -nocase {\.(mkv|mp4|avi|mov|wmv|m4v|iso)$} $name "" name
    regsub -- {-[^-._ ]+$} $name "" name
    set name [regsub -all {[\._]+} $name " "]
    regsub -all {[ ]+} [string trim $name] " " name

    set words [split $name " "]
    set metadataIndex [llength $words]
    set metadataPattern {^(480p|576p|720p|1080[pi]|2160p|4320p|uhd|xvid|divx|x26[45]|h[ .]?26[45]|hevc|av1|web|web-?dl|webrip|bluray|blu-?ray|b[dr]rip|dvd(?:rip)?|hd(?:tv|rip)|remux|cam|telesync|proper|repack|internal|limited|readnfo|multi|complete|s[0-9]{1,2}(?:e[0-9]{1,3})?|season|ddp?[0-9]*|eac3|ac3|aac|dts|truehd|atmos|flac|mp3)$}

    for {set index 0} {$index < [llength $words]} {incr index} {
        if {[regexp -nocase $metadataPattern [lindex $words $index]]} {
            set metadataIndex $index
            break
        }
    }

    set year ""
    if {$metadataIndex > 0} {
        set candidate [lindex $words [expr {$metadataIndex - 1}]]
        if {[regexp {^(18[89][0-9]|19[0-9]{2}|20[0-9]{2})$} $candidate]} {
            set year $candidate
            incr metadataIndex -1
        }
    }

    set title [join [lrange $words 0 [expr {$metadataIndex - 1}]] " "]
    regsub -all {[ ]+} [string trim $title] " " title

    return [dict create title $title year $year]
}

proc ::dZSbot::Modules::IMDb::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

::dZSbot::Modules::IMDb::Initialize
::dZSbot::ModuleManager::Register imdb [dict create \
    version $::dZSbot::Modules::IMDb::Version \
    domain movies \
    provider $::dZSbot::Modules::IMDb::Provider \
    description "Movies lookup using OMDb with IMDb-compatible commands" \
    commands [::dZSbot::Commands::List imdb]]
