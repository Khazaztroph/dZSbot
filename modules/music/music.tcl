namespace eval ::dZSbot::Modules::Music {

    variable Version "0.2.0"
    variable SupportedFormats [::dZSbot::Config::Get music.formats {mp3 flac}]
}

source [file join $::dZSbot::Root modules music parser.tcl]
source [file join $::dZSbot::Root modules music formatter.tcl]
source [file join $::dZSbot::Root modules music discogs.tcl]
source [file join $::dZSbot::Root modules music mp3.tcl]
source [file join $::dZSbot::Root modules music flac.tcl]

proc ::dZSbot::Modules::Music::Initialize {} {

    ::dZSbot::Transport::Subscribe site.release ::dZSbot::Modules::Music::OnSiteRelease
    ::dZSbot::Transport::Subscribe site.newdir ::dZSbot::Modules::Music::OnSiteRelease
}

proc ::dZSbot::Modules::Music::Lookup {query {format ""}} {

    set provider [string tolower [::dZSbot::Config::Get music.provider "discogs"]]

    switch -exact -- $provider {
        discogs {
            set fetched [::dZSbot::Modules::Music::Discogs::Fetch $query $format]
            if {![dict get $fetched ok]} {
                return [dict create ok 0 error [dict get $fetched error]]
            }

            return [::dZSbot::Modules::Music::Parser::ParseDiscogsSearch [dict get $fetched data]]
        }
        default {
            return [dict create ok 0 error "Unknown music provider: $provider"]
        }
    }
}

proc ::dZSbot::Modules::Music::CmdMusic {nick host hand chan text} {

    variable SupportedFormats
    set query [::dZSbot::Modules::Music::Parser::NormalizeQuery $text]

    if {$query eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !music <artist/title/release> or !flac <artist/title/release>"
        return
    }

    set format [::dZSbot::Modules::Music::Parser::GuessFormat $query]
    set result [Lookup $query $format]

    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply $nick $chan "Music: [dict get $result error]"
        return
    }

    ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Music::Formatter::FormatDiscogsRelease [dict get $result release]]
}

proc ::dZSbot::Modules::Music::CmdMusicStatus {nick host hand chan text} {

    variable SupportedFormats
    ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Music::Formatter::FormatStatus $SupportedFormats]
}

proc ::dZSbot::Modules::Music::OnSiteRelease {event payload} {

    if {![::dZSbot::Config::Get music.announce.enabled 1]} {
        return
    }

    set release [DictGet $payload release [file tail [DictGet $payload path ""]]]
    set section [string toupper [DictGet $payload section ""]]

    if {$release eq "" || ![ShouldLookupSection $section]} {
        return
    }

    set query [::dZSbot::Modules::Music::Parser::CleanReleaseName $release]
    set format [::dZSbot::Modules::Music::Parser::GuessFormat $release]
    set result [Lookup $query $format]
    set staffChan [::dZSbot::Config::Get music.announce.staff_channel "#staff"]

    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply "" $staffChan "Music lookup failed for $release: [dict get $result error]"
        return
    }

    set preChan [::dZSbot::Config::Get music.announce.pre_channel "#pre"]
    set found [dict get $result release]
    ::dZSbot::Commands::Reply "" $preChan [::dZSbot::Modules::Music::Formatter::PublicLine $found $release [PreTag $payload] $section]
    ::dZSbot::Commands::Reply "" $staffChan "Music details for $release:"
    ::dZSbot::Commands::Reply "" $staffChan [::dZSbot::Modules::Music::Formatter::FormatDiscogsRelease $found]
}

proc ::dZSbot::Modules::Music::PreTag {payload} {

    set preType [DictGet $payload pre_type ""]

    if {$preType in {PRE-MP3 PRE-FLAC}} {
        return $preType
    }

    return "Music"
}

proc ::dZSbot::Modules::Music::ShouldLookupSection {section} {

    if {$section eq ""} {
        return 1
    }

    foreach allowed [::dZSbot::Config::Get music.announce.sections {MUSIC MP3 FLAC}] {
        if {[string equal -nocase $allowed $section]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Music::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

::dZSbot::Commands::Register music !music ::dZSbot::Modules::Music::CmdMusic "Music lookup"
::dZSbot::Commands::Register music !flac ::dZSbot::Modules::Music::CmdMusic "Music lookup"
::dZSbot::Commands::Register music !musicinfo ::dZSbot::Modules::Music::CmdMusicStatus "Music module status"

::dZSbot::Modules::Music::Initialize
::dZSbot::ModuleManager::Register music [dict create \
    version $::dZSbot::Modules::Music::Version \
    provider [::dZSbot::Config::Get music.provider "discogs"] \
    description "Music lookup module for MP3, FLAC, and future formats" \
    formats $::dZSbot::Modules::Music::SupportedFormats \
    commands [::dZSbot::Commands::List music]]
