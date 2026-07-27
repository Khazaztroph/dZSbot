namespace eval ::dZSbot::Modules::Pre::Formatter {}

proc ::dZSbot::Modules::Pre::Formatter::Age {timestamp} {

    if {![string is integer -strict $timestamp] || $timestamp <= 0} {
        return "unknown"
    }

    set seconds [expr {[clock seconds] - $timestamp}]
    if {$seconds < 0} {
        set seconds 0
    }

    set days [expr {$seconds / 86400}]
    set hours [expr {($seconds % 86400) / 3600}]
    set mins [expr {($seconds % 3600) / 60}]

    if {$days > 0} {
        return "${days}d ${hours}h"
    }
    if {$hours > 0} {
        return "${hours}h ${mins}m"
    }

    return "${mins}m"
}

proc ::dZSbot::Modules::Pre::Formatter::Size {value} {

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

proc ::dZSbot::Modules::Pre::Formatter::Speed {value} {

    if {$value eq "" || ![string is double -strict $value]} {
        return "N/A"
    }

    if {$value >= 1024} {
        return [format "%.2f MB/s" [expr {$value / 1024.0}]]
    }

    return [format "%.0f KB/s" $value]
}

proc ::dZSbot::Modules::Pre::Formatter::Line {row {index ""}} {

    set release [dict get $row relname]
    set section [dict get $row section]
    set user [dict get $row u_name]
    set group [dict get $row g_name]
    set age [Age [dict get $row pretime]]
    set size [Size [dict get $row size]]
    set files [dict get $row files]

    set prefix "PRE"
    if {$index ne ""} {
        set prefix "PRE #$index"
    }

    return [::dZSbot::Theme::Render pre.result [dict create \
        section $section \
        prefix $prefix \
        release $release \
        age $age \
        user $user \
        group $group \
        size $size \
        files $files] {{prefix}: {release} | {section} | {age} ago | {user}/{group} | {size} | {files}F}]
}

proc ::dZSbot::Modules::Pre::Formatter::PublicLine {payload} {

    set preType [DictGet $payload pre_type "PRE"]
    set section [string toupper [DictGet $payload section "UNKNOWN"]]
    set release [DictGet $payload release [DictGet $payload relname ""]]
    set group [DictGet $payload group "UNKNOWN"]
    set files [DictGet $payload files "0"]
    set size [Size [DictGet $payload size ""]]

    return [::dZSbot::Theme::Render pre.public [dict create \
        section $section \
        tag $preType \
        release $release \
        group $group \
        files $files \
        size $size]]
}

proc ::dZSbot::Modules::Pre::Formatter::AnnounceLine {payload} {

    set style [string tolower [::dZSbot::Config::Get pre.announce.style "classic"]]

    if {$style eq "theme"} {
        return [PublicLine $payload]
    }

    set preType [DictGet $payload pre_type "PRE"]
    set release [DictGet $payload release [DictGet $payload relname ""]]
    set section [string toupper [DictGet $payload section "UNKNOWN"]]
    set group [DictGet $payload group "UNKNOWN"]
    set files [DictGet $payload files "0"]
    set size [Size [DictGet $payload size ""]]

    return [::dZSbot::Theme::Render pre.announce.classic [dict create \
        section $section \
        pre_type $preType \
        release $release \
        group $group \
        files $files \
        size $size] {{pre_type}: {release} | {section} | {group} | {files}F/{size}}]
}

proc ::dZSbot::Modules::Pre::Formatter::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

proc ::dZSbot::Modules::Pre::Formatter::StatsHeader {hours totals} {

    set releases [dict get $totals releases]
    set files [dict get $totals files]
    set size [Size [dict get $totals size]]

    return [::dZSbot::Theme::Render pre.stats.header [dict create \
        section PRE \
        hours $hours \
        releases $releases \
        files $files \
        size $size] {PRE Daily Stats: last {hours}h | {releases} releases | {files}F | {size}}]
}

proc ::dZSbot::Modules::Pre::Formatter::StatsTopLine {label rows} {

    set parts {}
    set index 0

    foreach row $rows {
        incr index
        lappend parts "#$index [dict get $row name] ([dict get $row count])"
    }

    set entries [join $parts { | }]
    if {$entries eq ""} {
        set entries "no data"
    }

    return [::dZSbot::Theme::Render pre.stats.top [dict create \
        section PRE \
        label $label \
        entries $entries] {PRE Top {label}: {entries}}]
}

proc ::dZSbot::Modules::Pre::Formatter::ActivityLine {section release delay sample} {

    set activity "N/A"
    if {[dict get $sample available]} {
        set activity "[dict get $sample users]@[Speed [dict get $sample speed]]"
    }

    return [::dZSbot::Theme::Render pre.activity [dict create \
        section $section \
        release $release \
        delay $delay \
        activity $activity] {PRE-BW: [{section}] {release} | {delay}s: {activity}}]
}
