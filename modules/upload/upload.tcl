namespace eval ::dZSbot::Modules::Upload {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Upload::Initialize {} {

    ::dZSbot::Transport::Subscribe site.newdir ::dZSbot::Modules::Upload::OnNewDir
    ::dZSbot::Transport::Subscribe site.upload.first ::dZSbot::Modules::Upload::OnFirst
    ::dZSbot::Transport::Subscribe site.upload.half ::dZSbot::Modules::Upload::OnHalf
    ::dZSbot::Transport::Subscribe site.upload.racer ::dZSbot::Modules::Upload::OnRacer
    ::dZSbot::Transport::Subscribe site.upload.leader ::dZSbot::Modules::Upload::OnLeader
    ::dZSbot::Transport::Subscribe site.upload.complete ::dZSbot::Modules::Upload::OnComplete
    ::dZSbot::Transport::Subscribe site.upload.badfile ::dZSbot::Modules::Upload::OnBadFile
    ::dZSbot::Transport::Subscribe site.upload.nfo ::dZSbot::Modules::Upload::OnNfo
    ::dZSbot::Transport::Subscribe site.upload.doublesfv ::dZSbot::Modules::Upload::OnDoubleSfv
    ::dZSbot::Transport::Subscribe site.upload.speedtest ::dZSbot::Modules::Upload::OnSpeedTest
    ::dZSbot::Transport::Subscribe site.upload.incomplete ::dZSbot::Modules::Upload::OnIncomplete
}

proc ::dZSbot::Modules::Upload::OnNewDir {event payload} {

    Announce newdir $payload
}

proc ::dZSbot::Modules::Upload::OnFirst {event payload} {

    Announce first $payload
}

proc ::dZSbot::Modules::Upload::OnHalf {event payload} {

    Announce half $payload
}

proc ::dZSbot::Modules::Upload::OnRacer {event payload} {

    Announce racer $payload
}

proc ::dZSbot::Modules::Upload::OnLeader {event payload} {

    Announce leader $payload
}

proc ::dZSbot::Modules::Upload::OnComplete {event payload} {

    Announce complete $payload
}

proc ::dZSbot::Modules::Upload::OnBadFile {event payload} {

    Announce badfile $payload
}

proc ::dZSbot::Modules::Upload::OnNfo {event payload} {

    Announce nfo $payload
}

proc ::dZSbot::Modules::Upload::OnDoubleSfv {event payload} {

    Announce doublesfv $payload
}

proc ::dZSbot::Modules::Upload::OnSpeedTest {event payload} {

    Announce speedtest $payload
}

proc ::dZSbot::Modules::Upload::OnIncomplete {event payload} {

    Announce incomplete $payload
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

    set channel [ChannelForSection $section]
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
    set sizeMb [::dZSbot::Modules::Upload::SizeMb [DictGet $payload size_mb ""]]
    if {$size eq "N/A" && $sizeMb ne "N/A"} {
        set size $sizeMb
    }
    set sizeCompact [::dZSbot::Modules::Upload::CompactUnit $size]
    set speed [::dZSbot::Modules::Upload::Speed [DictGet $payload speed_kbps [DictGet $payload avg_speed_kbps ""]]]
    set speedCompact [::dZSbot::Modules::Upload::CompactUnit $speed]
    set speedSuffix ""
    if {$speed ne "N/A"} {
        set speedSuffix " @ $speed"
    }
    set speedSegment ""
    if {$speedCompact ne "N/A"} {
        set speedSegment " :: avg. $speedCompact"
    }
    set duration [::dZSbot::Modules::Upload::Duration [DictGet $payload duration_seconds ""]]
    set durationSegment ""
    if {$duration ne "N/A"} {
        set durationSegment " :: $duration"
    }
    set eta [EtaLabel [DictGet $payload eta ""]]
    set etaSegment ""
    if {$eta ne ""} {
        set etaSegment " :: time left $eta"
    }
    set percent [PercentLabel [DictGet $payload percent ""]]
    set others [OthersLabel [DictGet $payload others ""]]
    set othersSegment ""
    if {$others ne ""} {
        set othersSegment " :: others: $others"
    }
    set filesLabel [::dZSbot::Modules::Upload::FilesLabel $files $eventName]
    set tag [expr {$eventName eq "complete" ? "COMPLETE" : "NEW"}]
    set file [DictGet $payload file ""]
    set reason [DictGet $payload reason ""]

    if {$eventName eq "first"} {
        return [::dZSbot::Theme::Render upload.first [dict create \
            tag FIRST \
            section $section \
            release $release \
            user $user \
            group $group \
            files $files \
            files_label $filesLabel \
            size $size \
            size_compact $sizeCompact \
            speed $speed \
            speed_compact $speedCompact \
            eta $eta \
            eta_segment $etaSegment \
            path $path]]
    }

    if {$eventName eq "half"} {
        return [::dZSbot::Theme::Render upload.half [dict create \
            tag HALF \
            section $section \
            release $release \
            user $user \
            group $group \
            files $files \
            files_label $filesLabel \
            size $size \
            size_compact $sizeCompact \
            speed $speed \
            speed_compact $speedCompact \
            percent $percent \
            others $others \
            others_segment $othersSegment \
            eta $eta \
            eta_segment $etaSegment \
            path $path]]
    }

    if {$eventName eq "racer"} {
        return [::dZSbot::Theme::Render upload.racer [dict create \
            tag RACER \
            section $section \
            release $release \
            user $user \
            group $group \
            file $file \
            files $files \
            files_label $filesLabel \
            total_files [DictGet $payload total_files ""] \
            percent $percent \
            speed $speed \
            speed_compact $speedCompact \
            eta $eta \
            eta_segment $etaSegment \
            path $path]]
    }

    if {$eventName eq "leader"} {
        return [::dZSbot::Theme::Render upload.leader [dict create \
            tag LEADER \
            section $section \
            release $release \
            user $user \
            group $group \
            file $file \
            files $files \
            files_label $filesLabel \
            percent $percent \
            speed $speed \
            speed_compact $speedCompact \
            eta $eta \
            eta_segment $etaSegment \
            path $path]]
    }

    if {$eventName eq "badfile"} {
        return [::dZSbot::Theme::Render upload.badfile [dict create \
            tag [string toupper $reason] \
            reason $reason \
            section $section \
            release $release \
            user $user \
            group $group \
            file $file \
            path $path]]
    }

    if {$eventName eq "nfo"} {
        return [::dZSbot::Theme::Render upload.nfo [dict create \
            tag NFO \
            section $section \
            release $release \
            user $user \
            group $group \
            file $file \
            path $path]]
    }

    if {$eventName eq "doublesfv"} {
        return [::dZSbot::Theme::Render upload.doublesfv [dict create \
            tag DOUBLESFV \
            section $section \
            release $release \
            user $user \
            group $group \
            file $file \
            path $path]]
    }

    if {$eventName eq "speedtest"} {
        return [::dZSbot::Theme::Render upload.speedtest [dict create \
            tag SPEED \
            section $section \
            release $release \
            user $user \
            group $group \
            size $size \
            size_compact $sizeCompact \
            speed $speed \
            speed_compact $speedCompact \
            path $path]]
    }

    if {$eventName eq "incomplete"} {
        return [::dZSbot::Theme::Render upload.incomplete [dict create \
            tag INCOMPLETE \
            section $section \
            release $release \
            user $user \
            group $group \
            path $path]]
    }

    if {$eventName eq "complete"} {
        return [::dZSbot::Theme::Render upload.complete [dict create \
            tag $tag \
            section $section \
            release $release \
            user $user \
            group $group \
            files $files \
            files_label $filesLabel \
            size $size \
            size_compact $sizeCompact \
            speed $speed \
            speed_compact $speedCompact \
            speed_suffix $speedSuffix \
            speed_segment $speedSegment \
            duration $duration \
            duration_segment $durationSegment \
            path $path]]
    }

    return [::dZSbot::Theme::Render upload.newdir [dict create \
        tag $tag \
        section $section \
        release $release \
        user $user \
        group $group \
        files $files \
        files_label $filesLabel \
        path $path]]
}

proc ::dZSbot::Modules::Upload::EventAllowed {eventName} {

    set defaultEnabled 1
    if {[string equal -nocase $eventName "racer"]} {
        set defaultEnabled 0
    }
    if {![::dZSbot::Config::Get "upload.announce.event.$eventName.enabled" $defaultEnabled]} {
        return 0
    }

    foreach allowed [::dZSbot::Config::Get upload.announce.events {newdir first half racer leader complete badfile nfo doublesfv speedtest incomplete}] {
        if {[string equal -nocase $allowed $eventName]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Upload::SectionAllowed {section} {

    foreach allowed [::dZSbot::Config::Get upload.announce.sections {MOVIES TV MUSIC MP3 FLAC AUDIOBOOKS GAMES PC CONSOLE EBOOKS}] {
        if {[::dZSbot::SiteAdapter::SectionMatches $section $allowed]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Upload::ChannelForSection {section} {

    set fallback [::dZSbot::Config::Get upload.announce.default_channel [::dZSbot::Config::Get upload.announce.channel "#pre"]]

    foreach route [::dZSbot::Config::Get upload.announce.section_channels {}] {
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

proc ::dZSbot::Modules::Upload::SectionMatchesRoute {section allowed} {

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

proc ::dZSbot::Modules::Upload::SizeMb {value} {

    if {$value eq "" || ![string is double -strict $value]} {
        return "N/A"
    }

    if {$value >= 1048576} {
        return [format "%.2f TB" [expr {$value / 1048576.0}]]
    }
    if {$value >= 1024} {
        return [format "%.2f GB" [expr {$value / 1024.0}]]
    }

    return [format "%.0f MB" $value]
}

proc ::dZSbot::Modules::Upload::FilesLabel {files eventName} {

    if {[string is integer -strict $files] && $files > 0} {
        if {$eventName in {half complete}} {
            return "${files}f"
        }
        return "$files file/s"
    }

    if {$eventName eq "complete"} {
        return "0f"
    }

    return "new dir"
}

proc ::dZSbot::Modules::Upload::Speed {value} {

    if {$value eq "" || ![string is double -strict $value]} {
        return "N/A"
    }

    if {$value >= 1048576} {
        return [format "%.2f GB/s" [expr {$value / 1048576.0}]]
    }
    if {$value >= 1024} {
        return [format "%.2f MB/s" [expr {$value / 1024.0}]]
    }

    return [format "%.0f KB/s" $value]
}

proc ::dZSbot::Modules::Upload::Duration {seconds} {

    if {![string is integer -strict $seconds] || $seconds < 0} {
        return "N/A"
    }

    set mins [expr {$seconds / 60}]
    set secs [expr {$seconds % 60}]

    if {$mins > 0} {
        return "${mins}m ${secs}s"
    }

    return "${secs}s"
}

proc ::dZSbot::Modules::Upload::EtaLabel {value} {

    set value [string trim $value]
    if {$value eq "" || $value eq "-"} {
        return ""
    }

    if {[string is integer -strict $value] && $value >= 0} {
        return [Duration $value]
    }

    return $value
}

proc ::dZSbot::Modules::Upload::PercentLabel {value} {

    if {$value eq "" || ![string is double -strict $value]} {
        return "N/A"
    }

    return [format "%.0f%%" $value]
}

proc ::dZSbot::Modules::Upload::OthersLabel {value} {

    set value [string trim $value]
    if {$value eq ""} {
        return ""
    }

    set result {}
    foreach item $value {
        if {[llength $item] >= 2} {
            lappend result "[lindex $item 0]/[lindex $item 1]"
        } else {
            lappend result $item
        }
    }

    return [join $result ", "]
}

proc ::dZSbot::Modules::Upload::CompactUnit {value} {

    if {$value eq "N/A"} {
        return $value
    }

    return [string map [list " GB/s" "GB/s" " MB/s" "MB/s" " KB/s" "KB/s" " GB" "GB" " MB" "MB" " KB" "KB"] $value]
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
