namespace eval ::dZSbot::Modules::Pre {

    variable Version "0.2.0"
    variable DailyStatsScheduled 0
}

source [file join $::dZSbot::Root modules pre store.tcl]
source [file join $::dZSbot::Root modules pre mysqlstore.tcl]
source [file join $::dZSbot::Root modules pre formatter.tcl]
source [file join $::dZSbot::Root modules pre nxtools.tcl]

::dZSbot::Modules::Pre::Store::Ready

proc ::dZSbot::Modules::Pre::Initialize {} {

    ::dZSbot::Transport::Subscribe site.release ::dZSbot::Modules::Pre::OnSiteRelease
    StartDailyStats
}

proc ::dZSbot::Modules::Pre::OnSiteRelease {event payload} {

    MaybeAnnouncePre $payload
    MaybeStartActivity $payload

    if {![::dZSbot::Config::Get pre.import_site_releases 1]} {
        return
    }

    if {[DictGet $payload source ""] ne "nxPre"} {
        return
    }

    set release [DictGet $payload release ""]
    if {$release eq "" || [AlreadyKnown $release]} {
        return
    }

    set entry [dict create \
        section [DictGet $payload section "UNKNOWN"] \
        relname $release \
        u_name [DictGet $payload user ""] \
        g_name [DictGet $payload group ""] \
        nukereason "" \
        size [DictGet $payload size ""] \
        files [DictGet $payload files ""]]

    ::dZSbot::Modules::Pre::Store::AddEntry $entry
}

proc ::dZSbot::Modules::Pre::MaybeAnnouncePre {payload} {

    if {![::dZSbot::Config::Get pre.announce.enabled 1]} {
        return 0
    }

    if {[DictGet $payload source ""] ne "nxPre"} {
        return 0
    }

    set section [string toupper [DictGet $payload section ""]]
    if {$section eq "" || ![SectionAllowed $section]} {
        return 0
    }

    set channel [::dZSbot::Config::Get pre.announce.channel "#pre"]
    ::dZSbot::Commands::Reply "" $channel [::dZSbot::Modules::Pre::Formatter::PublicLine $payload]
    return 1
}

proc ::dZSbot::Modules::Pre::SectionAllowed {section} {

    foreach allowed [::dZSbot::Config::Get pre.announce.sections {MOVIES TV MUSIC MP3 FLAC AUDIOBOOKS GAMES PC CONSOLE EBOOKS}] {
        if {[string equal -nocase $allowed $section]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Pre::MaybeStartActivity {payload} {

    if {![::dZSbot::Config::Get pre.activity.enabled 1]} {
        return 0
    }

    if {[DictGet $payload source ""] ne "nxPre"} {
        return 0
    }

    set release [DictGet $payload release ""]
    if {$release eq ""} {
        return 0
    }

    set intervals [::dZSbot::Config::Get pre.activity.intervals {5 10 15 25 30}]
    set scheduled 0

    foreach delay $intervals {
        if {![string is integer -strict $delay] || $delay < 0} {
            continue
        }

        if {[llength [info commands ::utimer]]} {
            ::utimer $delay [list ::dZSbot::Modules::Pre::AnnounceActivity $payload $delay]
            incr scheduled
        } elseif {[::dZSbot::Config::Get pre.activity.announce_when_unavailable 0]} {
            AnnounceActivity $payload $delay
            incr scheduled
        }
    }

    if {$scheduled > 0} {
        ::dZSbot::Health::Set pre:activity ok "scheduled"
    } else {
        ::dZSbot::Health::Set pre:activity disabled "utimer unavailable"
    }

    return $scheduled
}

proc ::dZSbot::Modules::Pre::AnnounceActivity {payload delay} {

    set channel [::dZSbot::Config::Get pre.activity.channel "#pre"]
    set sample [ActivitySample]
    set line [::dZSbot::Modules::Pre::Formatter::ActivityLine \
        [DictGet $payload section "UNKNOWN"] \
        [DictGet $payload release ""] \
        $delay \
        $sample]

    ::dZSbot::Commands::Reply "" $channel $line
}

proc ::dZSbot::Modules::Pre::ActivitySample {} {

    if {![llength [info commands ::ioftpd]]} {
        return [dict create available 0 users 0 speed 0 error "ioftpd command unavailable"]
    }

    set messageWindow [::dZSbot::Config::Get site.ioftpd.message_window "ioFTPD::MessageWindow"]

    if {[catch {
        set online [::ioftpd who $messageWindow "status user group speed vpath"]
    } error]} {
        return [dict create available 0 users 0 speed 0 error $error]
    }

    set users 0
    set speed 0.0

    foreach entry $online {
        foreach {status user group userSpeed vpath} $entry {
            break
        }

        if {$status == 1} {
            incr users
            if {[string is double -strict $userSpeed]} {
                set speed [expr {$speed + $userSpeed}]
            }
        }
    }

    return [dict create available 1 users $users speed $speed error ""]
}

proc ::dZSbot::Modules::Pre::AlreadyKnown {release} {

    foreach row [::dZSbot::Modules::Pre::Store::SearchEntries $release 10] {
        if {[string equal -nocase [dict get $row relname] $release]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::Modules::Pre::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

proc ::dZSbot::Modules::Pre::CmdPre {nick host hand chan text} {

    set query [string trim $text]
    set limit [::dZSbot::Config::Get pre.search_limit 5]
    set rows [::dZSbot::Modules::Pre::Store::SearchEntries $query $limit]

    if {![llength $rows]} {
        if {$query eq ""} {
            ::dZSbot::Commands::Reply $nick $chan "PRE: database is empty."
        } else {
            ::dZSbot::Commands::Reply $nick $chan "PRE: no match for '$query'"
        }
        return
    }

    set index 0
    foreach row $rows {
        incr index
        ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Pre::Formatter::Line $row $index]
    }
}

proc ::dZSbot::Modules::Pre::CmdAddPre {nick host hand chan text} {

    set parts [split [string trim $text]]
    set release [lindex $parts 0]

    if {$release eq ""} {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !addpre <release> ?section? ?user? ?group? ?size_kb? ?files?"
        return
    }

    set entry [dict create \
        section [expr {[lindex $parts 1] ne "" ? [lindex $parts 1] : "UNKNOWN"}] \
        relname $release \
        u_name [expr {[lindex $parts 2] ne "" ? [lindex $parts 2] : $nick}] \
        g_name [expr {[lindex $parts 3] ne "" ? [lindex $parts 3] : "UNKNOWN"}] \
        nukereason "" \
        size [lindex $parts 4] \
        files [lindex $parts 5]]

    set stored [::dZSbot::Modules::Pre::Store::AddEntry $entry]

    ::dZSbot::Commands::Reply $nick $chan "PRE added: [dict get $stored relname]"
}

proc ::dZSbot::Modules::Pre::CmdPres {nick host hand chan text} {

    set limit [::dZSbot::Config::Get pre.pres_limit 10]
    set rows [::dZSbot::Modules::Pre::Store::SearchEntries "" $limit]

    if {![llength $rows]} {
        ::dZSbot::Commands::Reply $nick $chan "PRE: database is empty."
        return
    }

    set index 0
    foreach row $rows {
        incr index
        ::dZSbot::Commands::Reply $nick $chan [::dZSbot::Modules::Pre::Formatter::Line $row $index]
    }
}

proc ::dZSbot::Modules::Pre::CmdPreImport {nick host hand chan text} {

    if {![AdminAllowed $nick $hand $chan]} {
        ::dZSbot::Commands::Reply $nick $chan "PRE import requires channel op in [::dZSbot::Config::Get status.admin_channel "#staff"]."
        return
    }

    set parts [split [string trim $text]]
    set source [string tolower [lindex $parts 0]]
    set path [lindex $parts 1]

    if {$source eq "" || $source eq "nxtools"} {
        ::dZSbot::Commands::Reply $nick $chan "PRE import started: nxTools..."
        if {[catch {set result [::dZSbot::Modules::Pre::NxTools::ImportPres $path]} error]} {
            ::dZSbot::Logger::Error "PRE import crashed: $error"
            ::dZSbot::Commands::Reply $nick $chan "PRE import failed: $error"
            return
        }
    } else {
        ::dZSbot::Commands::Reply $nick $chan "Usage: !preimport nxtools ?Pres.db path?"
        return
    }

    if {![dict get $result ok]} {
        ::dZSbot::Commands::Reply $nick $chan "PRE import failed: [dict get $result error]"
        return
    }

    ::dZSbot::Commands::Reply $nick $chan "PRE import complete: [dict get $result imported] imported, [dict get $result skipped] skipped, [dict get $result failed] failed."
}

proc ::dZSbot::Modules::Pre::AdminAllowed {nick hand chan} {

    set adminChan [::dZSbot::Config::Get status.admin_channel "#staff"]
    if {$adminChan ne "" && ![string equal -nocase $chan $adminChan]} {
        return 0
    }

    if {![::dZSbot::Config::Get status.require_channel_op 1]} {
        return 1
    }

    if {[llength [info commands ::isop]] && [::isop $nick $chan]} {
        return 1
    }

    if {[llength [info commands ::matchattr]] && $hand ne ""} {
        foreach flags {n m o} {
            if {[::matchattr $hand $flags $chan]} {
                return 1
            }
        }
    }

    if {![llength [info commands ::isop]] && ![llength [info commands ::matchattr]]} {
        return 1
    }

    return 0
}

proc ::dZSbot::Modules::Pre::StartDailyStats {} {

    variable DailyStatsScheduled

    if {![::dZSbot::Config::Get pre.daily_stats.enabled 1]} {
        return 0
    }

    if {![llength [info commands ::utimer]]} {
        ::dZSbot::Health::Set pre:daily-stats disabled "utimer unavailable"
        return 0
    }

    if {$DailyStatsScheduled} {
        return 1
    }

    set DailyStatsScheduled 1
    ScheduleDailyStats
    return 1
}

proc ::dZSbot::Modules::Pre::ScheduleDailyStats {} {

    set target [::dZSbot::Config::Get pre.daily_stats.time "23:59"]
    set delay [SecondsUntilTime $target]

    if {$delay < 60} {
        set delay 60
    }

    ::utimer $delay ::dZSbot::Modules::Pre::RunDailyStats
    ::dZSbot::Health::Set pre:daily-stats ok "scheduled"
    return $delay
}

proc ::dZSbot::Modules::Pre::RunDailyStats {} {

    set channel [::dZSbot::Config::Get pre.daily_stats.channel "#pre"]

    foreach line [DailyStatsLines] {
        ::dZSbot::Commands::Reply "" $channel $line
    }

    ScheduleDailyStats
}

proc ::dZSbot::Modules::Pre::DailyStatsLines {} {

    set hours [::dZSbot::Config::Get pre.daily_stats.window_hours 24]
    set limit [::dZSbot::Config::Get pre.daily_stats.top_limit 5]
    set rows [RowsSince [expr {[clock seconds] - ($hours * 3600)}]]
    set totals [StatsTotals $rows]

    set lines {}
    lappend lines [::dZSbot::Modules::Pre::Formatter::StatsHeader $hours $totals]
    lappend lines [::dZSbot::Modules::Pre::Formatter::StatsTopLine "Groups" [TopList $rows g_name $limit]]
    lappend lines [::dZSbot::Modules::Pre::Formatter::StatsTopLine "Sections" [TopList $rows section $limit]]

    return $lines
}

proc ::dZSbot::Modules::Pre::RowsSince {since} {

    set limit [::dZSbot::Config::Get pre.daily_stats.scan_limit 5000]
    set rows [::dZSbot::Modules::Pre::Store::SearchEntries "" $limit]
    set result {}

    foreach row $rows {
        set pretime [DictGet $row pretime 0]
        if {[string is integer -strict $pretime] && $pretime >= $since} {
            lappend result $row
        }
    }

    return $result
}

proc ::dZSbot::Modules::Pre::StatsTotals {rows} {

    set files 0
    set size 0

    foreach row $rows {
        set rowFiles [DictGet $row files 0]
        set rowSize [DictGet $row size 0]

        if {[string is integer -strict $rowFiles]} {
            incr files $rowFiles
        }
        if {[string is integer -strict $rowSize]} {
            incr size $rowSize
        }
    }

    return [dict create releases [llength $rows] files $files size $size]
}

proc ::dZSbot::Modules::Pre::TopList {rows field limit} {

    set counts {}

    foreach row $rows {
        set value [string toupper [DictGet $row $field "UNKNOWN"]]
        if {$value eq ""} {
            set value UNKNOWN
        }

        dict incr counts $value
    }

    set pairs {}
    dict for {name count} $counts {
        lappend pairs [list $count $name]
    }

    set result {}
    foreach pair [lrange [lsort -integer -decreasing -index 0 $pairs] 0 [expr {$limit - 1}]] {
        lappend result [dict create name [lindex $pair 1] count [lindex $pair 0]]
    }

    return $result
}

proc ::dZSbot::Modules::Pre::SecondsUntilTime {hhmm} {

    if {![regexp {^([0-9]{1,2}):([0-9]{2})$} $hhmm -> hour minute]} {
        set hour 23
        set minute 59
    }

    if {$hour > 23} {
        set hour 23
    }
    if {$minute > 59} {
        set minute 59
    }

    set now [clock seconds]
    set today [clock format $now -format "%Y-%m-%d"]
    set target [clock scan "$today [format {%02d:%02d:00} $hour $minute]"]

    if {$target <= $now} {
        set target [expr {$target + 86400}]
    }

    return [expr {$target - $now}]
}

::dZSbot::Commands::Register pre !pre ::dZSbot::Modules::Pre::CmdPre "Search PRE database"
::dZSbot::Commands::Register pre !pres ::dZSbot::Modules::Pre::CmdPres "Show latest PRE entries"
::dZSbot::Commands::Register pre !addpre ::dZSbot::Modules::Pre::CmdAddPre "Add PRE entry"
::dZSbot::Commands::Register pre !preimport ::dZSbot::Modules::Pre::CmdPreImport "Import PRE entries"

::dZSbot::Modules::Pre::Initialize
::dZSbot::ModuleManager::Register pre [dict create \
    version $::dZSbot::Modules::Pre::Version \
    description "PRE database" \
    commands [::dZSbot::Commands::List pre]]
