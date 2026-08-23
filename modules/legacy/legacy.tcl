namespace eval ::dZSbot::Modules::Legacy {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Legacy::Initialize {} {

    foreach eventName {wipe close open give take approve approveadd approvedel nuke unnuke request reqfill reqdel reqwipe newdate} {
        ::dZSbot::Transport::Subscribe "site.legacy.$eventName" ::dZSbot::Modules::Legacy::OnEvent
    }
}

proc ::dZSbot::Modules::Legacy::OnEvent {event payload} {

    set eventName [string range $event [string length "site.legacy."] end]
    Announce $eventName $payload
}

proc ::dZSbot::Modules::Legacy::Announce {eventName payload} {

    if {![::dZSbot::Config::Get legacy.announce.enabled 1]} {
        return 0
    }
    if {![EventAllowed $eventName]} {
        return 0
    }

    set section [string toupper [DictGet $payload section "UNKNOWN"]]
    set channel [ChannelForSection $section]
    ::dZSbot::Commands::Reply "" $channel [FormatLine $eventName $payload]
    return 1
}

proc ::dZSbot::Modules::Legacy::EventAllowed {eventName} {

    if {![::dZSbot::Config::Get "legacy.announce.event.$eventName.enabled" 1]} {
        return 0
    }

    foreach allowed [::dZSbot::Config::Get legacy.announce.events {wipe close open give take approve approveadd approvedel nuke unnuke request reqfill reqdel reqwipe newdate}] {
        if {[string equal -nocase $allowed $eventName]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Legacy::ChannelForSection {section} {

    set fallback [::dZSbot::Config::Get legacy.announce.default_channel [::dZSbot::Config::Get legacy.announce.channel "#pre"]]

    foreach route [::dZSbot::Config::Get legacy.announce.section_channels {}] {
        if {[llength $route] < 2} {
            continue
        }

        set channel [lindex $route 0]
        set sections [lindex $route 1]
        foreach allowed $sections {
            if {[SectionMatchesRoute $section $allowed]} {
                return $channel
            }
        }
    }

    return $fallback
}

proc ::dZSbot::Modules::Legacy::SectionMatchesRoute {section allowed} {

    set section [::dZSbot::SiteAdapter::NormalizeSection $section]
    set allowed [::dZSbot::SiteAdapter::NormalizeSection $allowed]

    if {$section eq "" || $allowed eq ""} {
        return 0
    }
    if {[string equal -nocase $allowed $section]} {
        return 1
    }
    if {[string match -nocase $allowed $section]} {
        return 1
    }
    if {[string match -nocase "${allowed}-*" $section]} {
        return 1
    }

    return 0
}

proc ::dZSbot::Modules::Legacy::FormatLine {eventName payload} {

    set values [BaseValues $payload]

    switch -- [string tolower $eventName] {
        wipe {
            return [::dZSbot::Theme::Render legacy.wipe $values]
        }
        close {
            return [::dZSbot::Theme::Render legacy.close $values]
        }
        open {
            return [::dZSbot::Theme::Render legacy.open $values]
        }
        give {
            return [::dZSbot::Theme::Render legacy.give $values]
        }
        take {
            return [::dZSbot::Theme::Render legacy.take $values]
        }
        approve -
        approveadd {
            return [::dZSbot::Theme::Render legacy.approve $values]
        }
        approvedel {
            return [::dZSbot::Theme::Render legacy.approvedel $values "%tag{approve}%tag{DEL} %bold{{release}} was just removed by %bold{{u_name}}/{g_name}"]
        }
        nuke {
            return [::dZSbot::Theme::Render legacy.nuke $values]
        }
        unnuke {
            return [::dZSbot::Theme::Render legacy.unnuke $values]
        }
        request {
            return [::dZSbot::Theme::Render requests.added $values]
        }
        reqfill {
            return [::dZSbot::Theme::Render requests.filled $values]
        }
        reqdel {
            return [::dZSbot::Theme::Render requests.deleted $values]
        }
        reqwipe {
            return [::dZSbot::Theme::Render legacy.reqwipe $values "%tag{req}%tag{WIPE} %bold{{u_name}}/{g_name} wiped %c2{{request}}."]
        }
        newdate {
            return [::dZSbot::Theme::Render legacy.newdate $values]
        }
    }

    return [::dZSbot::Theme::Render legacy.generic $values "%tag{legacy} {type}: {release}"]
}

proc ::dZSbot::Modules::Legacy::BaseValues {payload} {

    set release [DictGet $payload release [DictGet $payload relname ""]]
    set section [string toupper [DictGet $payload section "UNKNOWN"]]
    set user [DictGet $payload user [DictGet $payload u_name "UNKNOWN"]]
    set group [DictGet $payload group [DictGet $payload g_name "UNKNOWN"]]

    return [dict create \
        type [DictGet $payload type "LEGACY"] \
        section $section \
        path [DictGet $payload path ""] \
        release $release \
        relname [DictGet $payload relname $release] \
        reldir [DictGet $payload relname $release] \
        user $user \
        u_name [DictGet $payload u_name $user] \
        group $group \
        g_name [DictGet $payload g_name $group] \
        files [DictGet $payload files 0] \
        dirs [DictGet $payload dirs 0] \
        size [FormatSize [DictGet $payload size ""]] \
        credits [FormatSize [DictGet $payload credits ""]] \
        target [DictGet $payload target ""] \
        request [DictGet $payload request ""] \
        requester [DictGet $payload requester ""] \
        u_requester [DictGet $payload u_requester [DictGet $payload requester ""]] \
        request_id [DictGet $payload request_id ""] \
        age [DictGet $payload age ""] \
        max_age [DictGet $payload max_age ""] \
        sitename [DictGet $payload sitename [::dZSbot::Config::Get site.name "site"]] \
        duration [DictGet $payload duration ""] \
        reason [DictGet $payload reason ""] \
        multiplier [DictGet $payload multiplier ""] \
        nuker [DictGet $payload nuker $user] \
        nukees [DictGet $payload nukees ""] \
        multi [DictGet $payload multi [DictGet $payload multiplier ""]] \
        anuketime [DictGet $payload anuketime ""] \
        users [DictGet $payload users ""] \
        area [DictGet $payload area ""] \
        description [DictGet $payload description ""] \
        date [DictGet $payload date ""] \
        pattern [DictGet $payload pattern ""] \
        num [DictGet $payload num ""] \
        prebw [DictGet $payload prebw ""]]
}

proc ::dZSbot::Modules::Legacy::FormatSize {value} {

    if {$value eq "" || ![string is double -strict $value]} {
        return $value
    }

    if {$value >= 1048576} {
        return [format "%.2f GB" [expr {$value / 1048576.0}]]
    }
    if {$value >= 1024} {
        return [format "%.2f MB" [expr {$value / 1024.0}]]
    }

    return "${value} KB"
}

proc ::dZSbot::Modules::Legacy::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

::dZSbot::Modules::Legacy::Initialize

::dZSbot::ModuleManager::Register legacy [dict create \
    version $::dZSbot::Modules::Legacy::Version \
    description "pzs-ng/ioNiNJA compatibility announces"]
