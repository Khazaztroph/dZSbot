namespace eval ::dZSbot::Modules::TV {

    variable Version "0.2.0"
    variable Provider "omdb"
}

proc ::dZSbot::Modules::TV::Initialize {} {

    RegisterCommands
    ::dZSbot::Transport::Subscribe site.release ::dZSbot::Modules::TV::OnSiteRelease
    ::dZSbot::Transport::Subscribe site.newdir ::dZSbot::Modules::TV::OnSiteRelease
}

proc ::dZSbot::Modules::TV::RegisterCommands {} {

    ::dZSbot::Commands::Register tv !tv ::dZSbot::Modules::TV::CmdTV "TV lookup"
    ::dZSbot::Commands::Register tv !show ::dZSbot::Modules::TV::CmdTV "TV lookup"
}

proc ::dZSbot::Modules::TV::CmdTV {nick host hand chan text} {

    set query [string trim $text]

    if {$query eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !tv <show title>"
        return
    }

    set result [Lookup $query]
    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply $nick $chan "TV lookup failed: [dict get $result error]"
        return
    }

    foreach line [dict get $result lines] {
        ::dZSbot::Commands::Reply $nick $chan $line
    }
}

proc ::dZSbot::Modules::TV::Lookup {query} {

    set provider [string tolower [::dZSbot::Config::Get tv.provider "omdb"]]
    if {$provider eq ""} {
        set provider "omdb"
    }

    switch -exact -- $provider {
        omdb {
            set result [::dZSbot::Modules::IMDb::Lookup $query series]
            if {![dict get $result ok]} {
                return $result
            }
            return [dict create \
                ok 1 \
                title [dict get $result title] \
                lines [TVLines [dict get $result title]]]
        }
        default {
            return [dict create ok 0 error "unsupported TV provider: $provider"]
        }
    }
}

proc ::dZSbot::Modules::TV::OnSiteRelease {event payload} {

    if {![::dZSbot::Config::Get tv.announce.enabled 1]} {
        return
    }

    set release [ReleaseFromPayload $payload]
    set section [string toupper [DictGet $payload section ""]]

    if {$release eq "" || ![ShouldLookupSection $section]} {
        return
    }

    set query [CleanReleaseName $release]
    if {$query eq ""} {
        return
    }

    set result [Lookup $query]
    set staffChan [::dZSbot::Config::Get tv.announce.staff_channel "#staff"]

    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply "" $staffChan "TV lookup failed for $release: [dict get $result error]"
        return
    }

    set preChan [::dZSbot::Config::Get tv.announce.pre_channel "#pre"]
    set title [dict get $result title]

    ::dZSbot::Commands::Reply "" $preChan [PublicLine $title $release]
    ::dZSbot::Commands::Reply "" $staffChan "TV details for $release:"

    foreach line [dict get $result lines] {
        ::dZSbot::Commands::Reply "" $staffChan $line
    }
}

proc ::dZSbot::Modules::TV::TVLines {title} {

    return [::dZSbot::Modules::IMDb::Formatter::MovieLines $title]
}

proc ::dZSbot::Modules::TV::PublicLine {title {release ""}} {

    set titleName [dict get $title Title]
    set year [dict get $title Year]
    set rating [dict get $title imdbRating]
    set imdbid [dict get $title imdbID]
    set seasons [DictGet $title totalSeasons "N/A"]
    set releaseSuffix ""

    if {$release ne ""} {
        set releaseSuffix " | Rel: $release"
    }

    return [::dZSbot::Theme::Render tv.public [dict create \
        section TV \
        label "TV Series" \
        title $titleName \
        year $year \
        rating $rating \
        seasons $seasons \
        url "https://www.imdb.com/title/$imdbid/" \
        release_suffix $releaseSuffix]]
}

proc ::dZSbot::Modules::TV::ReleaseFromPayload {payload} {

    foreach key {release relname dirname path} {
        set value [DictGet $payload $key ""]
        if {$value ne ""} {
            return [file tail $value]
        }
    }

    return ""
}

proc ::dZSbot::Modules::TV::ShouldLookupSection {section} {

    if {$section eq ""} {
        return 0
    }

    set sections [::dZSbot::Config::Get tv.announce.sections {TV}]
    foreach allowed $sections {
        if {[string equal -nocase $allowed $section]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::TV::CleanReleaseName {release} {

    return [::dZSbot::Modules::IMDb::CleanReleaseName $release]
}

proc ::dZSbot::Modules::TV::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

::dZSbot::Modules::TV::Initialize
::dZSbot::ModuleManager::Register tv [dict create \
    version $::dZSbot::Modules::TV::Version \
    domain tv \
    provider $::dZSbot::Modules::TV::Provider \
    description "TV lookup compatibility module using OMDb series search" \
    commands [::dZSbot::Commands::List tv]]
