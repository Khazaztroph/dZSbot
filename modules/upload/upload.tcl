namespace eval ::dZSbot::Modules::Upload {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Upload::Initialize {} {

    ::dZSbot::Transport::Subscribe site.newdir ::dZSbot::Modules::Upload::OnNewDir
    ::dZSbot::Transport::Subscribe site.upload.complete ::dZSbot::Modules::Upload::OnComplete
}

proc ::dZSbot::Modules::Upload::OnNewDir {event payload} {

    Announce newdir $payload
}

proc ::dZSbot::Modules::Upload::OnComplete {event payload} {

    Announce complete $payload
}

proc ::dZSbot::Modules::Upload::Announce {eventName payload} {

    if {![::dZSbot::Config::Get upload.announce.enabled 1]} {
        return 0
    }

    if {![EventAllowed $eventName]} {
        return 0
    }

    set section [string toupper [DictGet $payload section "UNKNOWN"]]
    if {![SectionAllowed $section]} {
        return 0
    }

    set channel [::dZSbot::Config::Get upload.announce.channel "#pre"]
    ::dZSbot::Commands::Reply "" $channel [FormatLine $eventName $payload]
    return 1
}

proc ::dZSbot::Modules::Upload::FormatLine {eventName payload} {

    set release [DictGet $payload release [file tail [DictGet $payload path ""]]]
    set section [string toupper [DictGet $payload section "UNKNOWN"]]
    set user [DictGet $payload user "UNKNOWN"]
    set group [DictGet $payload group "UNKNOWN"]
    set path [DictGet $payload path ""]
    set files [DictGet $payload files ""]
    set size [::dZSbot::Modules::Upload::Size [DictGet $payload size ""]]
    set tag [expr {$eventName eq "complete" ? "COMPLETE" : "NEW"}]

    if {$eventName eq "complete"} {
        return [::dZSbot::Theme::Render upload.complete [dict create \
            tag $tag \
            section $section \
            release $release \
            user $user \
            group $group \
            files $files \
            size $size \
            path $path]]
    }

    return [::dZSbot::Theme::Render upload.newdir [dict create \
        tag $tag \
        section $section \
        release $release \
        user $user \
        group $group \
        path $path]]
}

proc ::dZSbot::Modules::Upload::EventAllowed {eventName} {

    foreach allowed [::dZSbot::Config::Get upload.announce.events {newdir complete}] {
        if {[string equal -nocase $allowed $eventName]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Upload::SectionAllowed {section} {

    foreach allowed [::dZSbot::Config::Get upload.announce.sections {MOVIES TV MUSIC MP3 FLAC AUDIOBOOKS GAMES PC CONSOLE EBOOKS}] {
        if {[string equal -nocase $allowed $section]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Upload::Size {value} {

    if {$value eq "" || ![string is double -strict $value]} {
        return "N/A"
    }

    if {$value >= 1048576} {
        return [format "%.2f GB" [expr {$value / 1048576.0}]]
    }
    if {$value >= 1024} {
        return [format "%.2f MB" [expr {$value / 1024.0}]]
    }

    return "${value} KB"
}

proc ::dZSbot::Modules::Upload::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

::dZSbot::Modules::Upload::Initialize
::dZSbot::ModuleManager::Register upload [dict create \
    version $::dZSbot::Modules::Upload::Version \
    description "Site upload announcements" \
    commands [::dZSbot::Commands::List upload]]
