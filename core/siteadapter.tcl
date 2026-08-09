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

    if {[regexp {(UPDATE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdFirst $type $data]
    }

    if {[regexp {(HALFWAY_(?:NO)?RACE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdHalf $type $data]
    }

    if {[regexp {(COMPLETE_STAT_RACE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdComplete $type $data]
    }

    if {[regexp {(COMPLETE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdComplete $type $data]
    }

    if {[regexp {(RACE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdRacer $type $data]
    }

    if {[regexp {(NEWLEADER_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdLeader $type $data]
    }

    if {[regexp {(BAD_FILE_[A-Z0-9_]+):[ \t]*(.*)$} $line -> type data]} {
        return [ParseIoFtpdBadFile $type $data]
    }

    if {[regexp {NFO:[ \t]*(.*)$} $line -> data]} {
        return [ParseIoFtpdNfo $data]
    }

    if {[regexp {DOUBLESFV:[ \t]*(.*)$} $line -> data]} {
        return [ParseIoFtpdDoubleSfv $data]
    }

    if {[regexp {SPEEDTEST:[ \t]*(.*)$} $line -> data]} {
        return [ParseIoFtpdSpeedTest $data]
    }

    if {[regexp {INCOMPLETE:[ \t]*(.*)$} $line -> data]} {
        return [ParseIoFtpdIncomplete $data]
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

proc ::dZSbot::SiteAdapter::ParseIoFtpdFirst {type data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 8} {
        return [dict create ok 0 error "invalid UPDATE payload"]
    }

    set path [lindex $data 0]
    set user [lindex $data 1]
    set group [lindex $data 2]
    set release [lindex $data 7]
    set section [InferSection $path]

    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action first \
        update_type $type \
        path $path \
        release $release \
        relname $release \
        section $section \
        user $user \
        group $group \
        files [lindex $data 3] \
        speed_kbps [lindex $data 4] \
        size [lindex $data 5]]

    if {$fieldCount >= 10} {
        dict set payload eta [lindex $data 9]
    }

    return [dict create ok 1 event site.upload.first payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdHalf {type data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 18} {
        return [dict create ok 0 error "invalid HALFWAY payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 1]
    set user [lindex $data 2]
    set group [lindex $data 3]
    set section [InferSection $path]

    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action half \
        halfway_type $type \
        path $path \
        release $release \
        relname $release \
        section $section \
        user $user \
        group $group \
        size_mb [lindex $data 4] \
        files [lindex $data 5] \
        percent [lindex $data 6] \
        speed_kbps [lindex $data 7]]

    if {[string match -nocase "HALFWAY_RACE_*" $type]} {
        if {$fieldCount >= 26} {
            dict set payload others [lindex $data 25]
        }
        if {$fieldCount >= 27} {
            dict set payload eta [lindex $data 26]
        }
    } elseif {$fieldCount >= 26} {
        dict set payload eta [lindex $data 25]
    }

    return [dict create ok 1 event site.upload.half payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdRacer {type data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 7} {
        return [dict create ok 0 error "invalid RACE payload"]
    }

    set path [lindex $data 0]
    set user [lindex $data 1]
    set group [lindex $data 2]
    set release [lindex $data 4]
    set section [InferSection $path]

    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action racer \
        race_type $type \
        path $path \
        release $release \
        relname $release \
        section $section \
        user $user \
        group $group \
        others [lindex $data 3] \
        speed_kbps [lindex $data 5] \
        file [lindex $data 6]]

    if {$fieldCount >= 8} {
        dict set payload duration_seconds [lindex $data 7]
    }
    if {$fieldCount >= 9} {
        dict set payload percent [lindex $data 8]
    }
    if {$fieldCount >= 13} {
        dict set payload files [lindex $data 11]
        dict set payload total_files [lindex $data 12]
    }
    if {$fieldCount >= 17} {
        dict set payload active_others [lindex $data 15]
        dict set payload eta [lindex $data 16]
    }

    return [dict create ok 1 event site.upload.racer payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdLeader {type data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 15} {
        return [dict create ok 0 error "invalid NEWLEADER payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 8]
    set section [InferSection $path]

    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action leader \
        leader_type $type \
        path $path \
        release $release \
        relname $release \
        section $section \
        user [lindex $data 14] \
        group [lindex $data 15] \
        speed_kbps [lindex $data 3] \
        duration_seconds [lindex $data 4] \
        files [lindex $data 5] \
        percent [lindex $data 6] \
        size [lindex $data 7] \
        file [lindex $data 9]]

    if {$fieldCount >= 28} {
        dict set payload others [lindex $data 27]
    }
    if {$fieldCount >= 29} {
        dict set payload eta [lindex $data 28]
    }

    return [dict create ok 1 event site.upload.leader payload $payload]
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

    if {[string match -nocase "COMPLETE_STAT_RACE_*" $type] && $fieldCount >= 11} {
        set user [lindex $data 9]
        set group [lindex $data 10]
    } elseif {$fieldCount >= 9} {
        set user [lindex $data 7]
        set group [lindex $data 8]
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

    if {$fieldCount >= 5} {
        dict set payload speed_kbps [lindex $data 4]
        dict set payload avg_speed_kbps [lindex $data 4]
    }
    if {$fieldCount >= 6} {
        dict set payload race_speed_kbps [lindex $data 5]
    }
    if {$fieldCount >= 7} {
        dict set payload duration_seconds [lindex $data 6]
    }

    return [dict create ok 1 event site.upload.complete payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdBadFile {type data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 5} {
        return [dict create ok 0 error "invalid BAD_FILE payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 1]
    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action badfile \
        bad_type $type \
        reason [BadFileReason $type] \
        path $path \
        release $release \
        relname $release \
        section [InferSection $path] \
        user [lindex $data 2] \
        group [lindex $data 3] \
        file [lindex $data 4]]

    return [dict create ok 1 event site.upload.badfile payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdNfo {data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 5} {
        return [dict create ok 0 error "invalid NFO payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 3]
    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action nfo \
        path $path \
        release $release \
        relname $release \
        section [InferSection $path] \
        user [lindex $data 1] \
        group [lindex $data 2] \
        file [lindex $data 4]]

    return [dict create ok 1 event site.upload.nfo payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdDoubleSfv {data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 5} {
        return [dict create ok 0 error "invalid DOUBLESFV payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 3]
    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action doublesfv \
        path $path \
        release $release \
        relname $release \
        section [InferSection $path] \
        user [lindex $data 1] \
        group [lindex $data 2] \
        file [lindex $data 4]]

    return [dict create ok 1 event site.upload.doublesfv payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdSpeedTest {data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 6} {
        return [dict create ok 0 error "invalid SPEEDTEST payload"]
    }

    set path [lindex $data 0]
    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action speedtest \
        path $path \
        release [file tail [string trimright $path "/"]] \
        section [InferSection $path] \
        user [lindex $data 1] \
        group [lindex $data 2] \
        tagline [lindex $data 3] \
        speed_kbps [lindex $data 4] \
        size_mb [lindex $data 5]]

    return [dict create ok 1 event site.upload.speedtest payload $payload]
}

proc ::dZSbot::SiteAdapter::ParseIoFtpdIncomplete {data} {

    if {[catch {llength $data} fieldCount] || $fieldCount < 4} {
        return [dict create ok 0 error "invalid INCOMPLETE payload"]
    }

    set path [lindex $data 0]
    set release [lindex $data 3]
    set payload [dict create \
        adapter ioftpd \
        source ioFTPD \
        action incomplete \
        path $path \
        release $release \
        relname $release \
        section [InferSection $path] \
        user [lindex $data 1] \
        group [lindex $data 2]]

    return [dict create ok 1 event site.upload.incomplete payload $payload]
}

proc ::dZSbot::SiteAdapter::BadFileReason {type} {

    switch -nocase -- $type {
        BAD_FILE_0SIZE {return "0size"}
        BAD_FILE_CRC {return "badcrc"}
        BAD_FILE_BITRATE {return "badbitrate"}
        BAD_FILE_DISALLOWED {return "badfiletype"}
        BAD_FILE_DUPENFO {return "dupenfo"}
        BAD_FILE_GENRE {return "badgenre"}
        BAD_FILE_NOSFV {return "nosfv"}
        BAD_FILE_SFV {return "badsfv"}
        BAD_FILE_WRONGDIR {return "wrongdir"}
        BAD_FILE_YEAR {return "badyear"}
        BAD_FILE_ZIP {return "badzip"}
        BAD_FILE_ZIPNFO {return "badzipnfo"}
        BAD_FILE_DUPERELEASE {return "dupefile"}
    }

    return [string tolower [string map [list BAD_FILE_ ""] $type]]
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

proc ::dZSbot::SiteAdapter::SectionMatches {section allowed} {

    set section [NormalizeSection $section]
    set allowed [NormalizeSection $allowed]

    if {$section eq "" || $allowed eq ""} {
        return 0
    }

    if {[string equal -nocase $allowed $section]} {
        return 1
    }

    if {[string first "*" $allowed] >= 0 && [string match -nocase $allowed $section]} {
        return 1
    }

    set sectionFamily [SectionFamily $section]
    set allowedFamily [SectionFamily $allowed]
    if {$sectionFamily ne "" && $allowedFamily ne "" && $sectionFamily eq $allowedFamily} {
        return 1
    }

    foreach delimiter {- _ .} {
        if {[string match -nocase "${allowed}${delimiter}*" $section]} {
            return 1
        }
    }

    return 0
}

proc ::dZSbot::SiteAdapter::NormalizeSection {section} {

    return [string toupper [string trim $section " \t\r\n/"]]
}

proc ::dZSbot::SiteAdapter::SectionFamily {section} {

    set section [NormalizeSection $section]

    switch -glob -- $section {
        MOVIE - MOVIE-* - MOVIES - MOVIES-* - UHD - UHD-* {
            return MOVIES
        }
        TV - TV-* {
            return TV
        }
        MUSIC - MUSIC-* - MUSiC - MUSiC-* - MP3 - MP3-* - FLAC - FLAC-* {
            return MUSIC
        }
        AUDIOBOOK - AUDIOBOOK-* - AUDIOBOOKS - AUDIOBOOKS-* {
            return AUDIOBOOKS
        }
        GAME - GAME-* - GAMES - GAMES-* - PC - PC-* {
            return GAMES
        }
        CONSOLE - CONSOLE-* {
            return CONSOLE
        }
        EBOOK - EBOOK-* - EBOOKS - EBOOKS-* {
            return EBOOKS
        }
    }

    return $section
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
