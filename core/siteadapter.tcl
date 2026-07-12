###############################################################################
#
# dZSbot 2.0
#
# Module      : Site Adapter
# Description : Site daemon adapter policy and registry.
#
###############################################################################

namespace eval ::dZSbot::SiteAdapter {

    variable Adapters
    variable WatchOffsets
    array set Adapters {}
    array set WatchOffsets {}
}

proc ::dZSbot::SiteAdapter::Register {name metadata} {

    variable Adapters

    set normalized [string tolower $name]
    dict set metadata name $normalized
    set Adapters($normalized) $metadata

    ::dZSbot::Health::Set "adapter:$normalized" ok "registered"
    return $Adapters($normalized)
}

proc ::dZSbot::SiteAdapter::Get {name} {

    variable Adapters
    set normalized [string tolower $name]

    if {[info exists Adapters($normalized)]} {
        return $Adapters($normalized)
    }

    return {}
}

proc ::dZSbot::SiteAdapter::Selected {} {

    return [string tolower [::dZSbot::Config::Get site.adapter "ioftpd"]]
}

proc ::dZSbot::SiteAdapter::Policy {} {

    return [dict create \
        adapter [Selected] \
        host [::dZSbot::Config::Get site.host "127.0.0.1"] \
        port [::dZSbot::Config::Get site.port 5420] \
        user [::dZSbot::Config::Get site.user ""] \
        config_path [::dZSbot::Config::Get site.ioftpd.config_path "C:/ioFTPD/system/ioFTPD.ini"] \
        log_path [::dZSbot::Config::Get site.ioftpd.log_path "C:/ioFTPD/logs"] \
        message_window [::dZSbot::Config::Get site.ioftpd.message_window "ioFTPD::MessageWindow"] \
        command_transport [::dZSbot::Config::Get site.command_transport "ftps"] \
        event_transport [::dZSbot::Config::Get site.event_transport "local"] \
        passive [::dZSbot::Config::Get site.passive 1] \
        passive_ports [::dZSbot::Config::Get site.passive_ports "5421-5450"] \
        tls_required [::dZSbot::Config::Get site.tls.required 1] \
        tls_min_version [::dZSbot::Config::Get site.tls.min_version "1.3"] \
        allow_plain_event_source [::dZSbot::Config::Get site.allow_plain_event_source 1]]
}

proc ::dZSbot::SiteAdapter::ValidatePolicy {} {

    set policy [Policy]

    if {[dict get $policy tls_required] && [dict get $policy command_transport] ni {ftps sftp https local}} {
        ::dZSbot::Health::Set siteadapter error "TLS required but command transport is not secure"
        return 0
    }

    ::dZSbot::Health::Set siteadapter ok "policy ready"
    return 1
}

proc ::dZSbot::SiteAdapter::ParseNxPreLine {line} {

    if {![regexp {(PRE(?:-(?:MP3|FLAC))?):[ \t]*(.*)$} $line -> type data]} {
        return [dict create ok 0 error "not an nxPre PRE line"]
    }

    if {[catch {llength $data} fieldCount] || $fieldCount < 8} {
        return [dict create ok 0 error "invalid nxPre PRE payload"]
    }

    set path [lindex $data 0]
    set preGroup [lindex $data 1]
    set user [lindex $data 2]
    set userGroup [lindex $data 3]
    set area [string toupper [lindex $data 4]]
    set files [lindex $data 5]
    set size [lindex $data 6]
    set disks [lindex $data 7]
    set release [file tail $path]

    set payload [dict create \
        adapter ioftpd \
        source nxPre \
        pre_type $type \
        path $path \
        release $release \
        relname $release \
        section $area \
        user $user \
        group $preGroup \
        uploader_group $userGroup \
        files $files \
        size $size \
        disks $disks]

    if {$type in {PRE-MP3 PRE-FLAC} && $fieldCount >= 14} {
        dict set payload music.format [string range $type 4 end]
        dict set payload music.artist [lindex $data 8]
        dict set payload music.album [lindex $data 9]
        dict set payload music.genre [lindex $data 10]
        dict set payload music.year [lindex $data 11]
        dict set payload music.bitrate [lindex $data 12]
        dict set payload music.type [lindex $data 13]
    }

    return [dict create ok 1 event site.release payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdLine {line} {

    set line [string trim $line]

    if {[regexp {NEWDIR:[ \t]*(.*)$} $line -> data]} {
        return [ParseIoFtpdNewDir $data]
    }

    if {[regexp {(COMPLETE_STAT_RACE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdComplete $type $data]
    }

    return [dict create ok 0 error "not a supported ioFTPD event line"]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdNewDir {data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 3} {
        return [dict create ok 0 error "invalid NEWDIR payload"]
    }

    set user [lindex $data 0]
    set group [lindex $data 1]
    set path [lindex $data 2]
    set release [file tail [string trimright $path "/"]]
    set section [InferSection $path]

    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action newdir \
        path $path \
        release $release \
        relname $release \
        section $section \
        user $user \
        group $group]

    if {$fieldCount >= 4} {
        dict set payload realpath [lindex $data 3]
    }

    return [dict create ok 1 event site.newdir payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdComplete {type data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 4} {
        return [dict create ok 0 error "invalid COMPLETE payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 1]
    set section [InferSection $path]
    set user ""
    set group ""

    if {$fieldCount >= 11} {
        set user [lindex $data 9]
        set group [lindex $data 10]
    }

    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action complete \
        complete_type $type \
        path $path \
        release $release \
        relname $release \
        section $section \
        size [lindex $data 2] \
        files [lindex $data 3] \
        user $user \
        group $group]

    return [dict create ok 1 event site.upload.complete payload $payload]
}

proc ::dZSbot::SiteAdapter::InferSection {path} {

    set normalized [string toupper [string trim $path "/"]]
    set parts [split $normalized "/"]
    set skipNext 0

    for {set index 0} {$index < [llength $parts]} {incr index} {
        set part [lindex $parts $index]
        if {$part eq ""} {
            continue
        }
        if {$part eq "GROUPS"} {
            set skipNext 1
            continue
        }
        if {$skipNext} {
            set skipNext 0
            continue
        }
        if {$part in {INCOMING INCOMiNG}} {
            continue
        }
        if {[string match {[0-9][0-9][0-9][0-9]} $part]} {
            continue
        }
        switch -glob -- $part {
            MOVIE - MOVIES - MOViES {return MOVIES}
            TV {return TV}
            MUSIC - MUSiC - MP3 - FLAC {return MUSIC}
            AUDIOBOOK - AUDIOBOOKS {return AUDIOBOOKS}
            GAME - GAMES - PC {return PC}
            CONSOLE {return CONSOLE}
            EBOOK - EBOOKS {return EBOOKS}
            default {return $part}
        }
    }

    return UNKNOWN
}

proc ::dZSbot::SiteAdapter::ImportNxPreLine {line} {

    set parsed [ParseNxPreLine $line]
    if {![dict get $parsed ok]} {
        set parsed [ParseIoFtpdLine $line]
        if {![dict get $parsed ok]} {
            return 0
        }
    }

    return [::dZSbot::Transport::Publish [dict get $parsed event] [dict get $parsed payload]]
}

proc ::dZSbot::SiteAdapter::StartNxPreWatcher {} {

    if {![::dZSbot::Config::Get site.ioftpd.nxpre_watch.enabled 0]} {
        return 0
    }

    if {![llength [info commands ::utimer]]} {
        ::dZSbot::Health::Set siteadapter:nxpre-log disabled "utimer unavailable"
        return 0
    }

    PollNxPreLog
    return 1
}

proc ::dZSbot::SiteAdapter::PollNxPreLog {} {

    variable WatchOffsets

    set path [::dZSbot::Config::Get site.ioftpd.nxpre_log_file "C:/ioFTPD/logs/ioFTPD.log"]
    set interval [::dZSbot::Config::Get site.ioftpd.nxpre_poll_seconds 5]

    if {![file exists $path]} {
        ::dZSbot::Health::Set siteadapter:nxpre-log warn "log not found"
        ScheduleNxPrePoll $interval
        return 0
    }

    set size [file size $path]
    if {![info exists WatchOffsets($path)]} {
        if {[::dZSbot::Config::Get site.ioftpd.nxpre_start_at_end 1]} {
            set WatchOffsets($path) $size
        } else {
            set WatchOffsets($path) 0
        }
    }

    if {$size < $WatchOffsets($path)} {
        set WatchOffsets($path) 0
    }

    if {[catch {
        set handle [open $path r]
        seek $handle $WatchOffsets($path) start
        set data [read $handle]
        set WatchOffsets($path) [tell $handle]
        close $handle
    } error]} {
        catch {close $handle}
        ::dZSbot::Health::Set siteadapter:nxpre-log error $error
        ScheduleNxPrePoll $interval
        return 0
    }

    set imported 0
    foreach line [split $data "\n"] {
        if {[ImportNxPreLine [string trimright $line "\r"]] > 0} {
            incr imported
        }
    }

    ::dZSbot::Health::Set siteadapter:nxpre-log ok "watching"
    ::dZSbot::Metrics::Set "siteadapter.nxpre.imported" $imported
    ScheduleNxPrePoll $interval
    return $imported
}

proc ::dZSbot::SiteAdapter::ScheduleNxPrePoll {interval} {

    if {[llength [info commands ::utimer]]} {
        ::utimer $interval ::dZSbot::SiteAdapter::PollNxPreLog
    }
}

::dZSbot::SiteAdapter::Register ioftpd [dict create \
    description "ioFTPD adapter" \
    event_sources {local logs scripts} \
    command_transports {ftps local}]

::dZSbot::SiteAdapter::Register glftpd [dict create \
    description "glFTPD adapter" \
    event_sources {local logs scripts} \
    command_transports {ftps sftp local}]

::dZSbot::SiteAdapter::Register drftpd [dict create \
    description "drFTPD adapter" \
    event_sources {api logs} \
    command_transports {https ftps}]
