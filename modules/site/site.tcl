namespace eval ::dZSbot::Modules::Site {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Site::CmdDf {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan]

    if {![::dZSbot::Config::Get site.commands.df.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: command is disabled."
        return
    }

    set filter [string toupper [string trim $text]]
    set lines {}
    set source [string tolower [::dZSbot::Config::Get site.commands.df.source "cache"]]

    set sections [DfSections]
    if {$source ni {auto cache file status fluxftp api} && ![llength $sections]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: no sections configured. Set site.df.sections in config/modules/site.conf."
        return
    }

    if {$source in {auto fluxftp api}} {
        set api [FluxFtpDfLines $filter]
        if {[dict get $api ok]} {
            set lines [dict get $api lines]
        } elseif {$source ni {auto} && [DfFallbackEnabled]} {
            set fallback [DfCacheLines $filter]
            if {[dict get $fallback ok]} {
                set lines [dict get $fallback lines]
            } else {
                lappend lines "DF: ERROR | [dict get $api error]; fallback failed: [dict get $fallback error]"
            }
        } elseif {$source ni {auto}} {
            lappend lines "DF: ERROR | [dict get $api error]"
        }
    }

    if {![llength $lines] && $source in {auto cache file status}} {
        set cache [DfCacheLines $filter]
        if {[dict get $cache ok]} {
            set lines [dict get $cache lines]
        } elseif {$source ni {auto}} {
            lappend lines "DF: ERROR | [dict get $cache error]"
        }
    }

    if {![llength $lines] && $source eq "auto" && [llength $sections]} {
        foreach section $sections {
            if {![dict get $section ok]} {
                lappend lines "DF: invalid section config | [dict get $section error]"
                continue
            }

            set name [string toupper [dict get $section name]]
            set path [dict get $section path]
            if {$filter ne "" && ![string match "*$filter*" $name]} {
                continue
            }

            lappend lines [FormatDfLine $name $path [DiskFree $path]]
        }
    } elseif {$source ni {auto cache file status fluxftp api}} {
        foreach section $sections {
            if {![dict get $section ok]} {
                lappend lines "DF: invalid section config | [dict get $section error]"
                continue
            }

            set name [string toupper [dict get $section name]]
            set path [dict get $section path]
            if {$filter ne "" && ![string match "*$filter*" $name]} {
                continue
            }

            lappend lines [FormatDfLine $name $path [DiskFree $path]]
        }
    }

    if {![llength $lines]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: no configured section matched '$text'."
        return
    }

    foreach line $lines {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::DfSections {} {

    set raw [::dZSbot::Config::Get site.df.sections {}]
    set result {}

    if {![catch {dict size $raw} size] && $size > 0} {
        dict for {name path} $raw {
            lappend result [dict create ok 1 name $name path $path]
        }
        return $result
    }

    foreach section $raw {
        lappend result [ParseDfSection $section]
    }

    return $result
}

proc ::dZSbot::Modules::Site::ParseDfSection {section} {

    if {[catch {set count [llength $section]} error]} {
        return [dict create ok 0 error $error]
    }

    if {$count < 2} {
        return [dict create ok 0 error "expected {NAME PATH}"]
    }

    set name [lindex $section 0]
    set path [lindex $section 1]

    if {[string trim $name] eq "" || [string trim $path] eq ""} {
        return [dict create ok 0 error "empty name or path"]
    }

    return [dict create ok 1 name $name path $path]
}

proc ::dZSbot::Modules::Site::DfCacheLines {filter} {

    set path [::dZSbot::Config::Get site.commands.df.cache_file ""]
    if {$path eq ""} {
        return [dict create ok 0 error "site.commands.df.cache_file not configured" lines {}]
    }
    if {![file exists $path]} {
        return [dict create ok 0 error "DF cache file not found: $path" lines {}]
    }

    set maxAge [::dZSbot::Config::Get site.commands.df.cache_max_age_seconds 300]
    if {![string is integer -strict $maxAge] || $maxAge < 1} {
        set maxAge 300
    }

    set age [expr {[clock seconds] - [file mtime $path]}]
    if {$age > $maxAge} {
        return [dict create ok 0 error "DF cache is stale (${age}s old)" lines {}]
    }

    if {[catch {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8 -translation lf
        set content [read $fh]
        close $fh
    } error]} {
        catch {close $fh}
        return [dict create ok 0 error $error lines {}]
    }

    set lines {}
    foreach rawLine [split $content "\n"] {
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq "" || [string match "#*" [string trimleft $rawLine]]} {
            continue
        }

        set entry [ParseDfCacheLine $rawLine]
        if {![dict get $entry ok]} {
            if {[dict exists $entry name] && [dict exists $entry path]} {
                lappend lines [FormatDfLine [string toupper [dict get $entry name]] [dict get $entry path] $entry]
            }
            continue
        }

        set name [string toupper [dict get $entry name]]
        if {$filter ne "" && ![string match "*$filter*" $name]} {
            continue
        }

        lappend lines [FormatDfLine $name [dict get $entry path] $entry]
    }

    return [dict create ok 1 error "" lines $lines]
}

proc ::dZSbot::Modules::Site::FluxFtpDfLines {filter} {

    if {![FluxFtpAvailable]} {
        return [dict create ok 0 error "FluxFTP adapter unavailable" lines {}]
    }

    if {[catch {set result [::dZSbot::Adapter::FluxFTP::DiskFree]} error]} {
        return [dict create ok 0 error $error lines {}]
    }
    if {![dict get $result ok]} {
        return [dict create ok 0 error [DictGet $result error "FluxFTP diskfree failed"] lines {}]
    }

    set lines {}
    foreach section [DictGet $result sections {}] {
        set name [string toupper [DictGet $section name "UNKNOWN"]]
        if {$filter ne "" && ![string match "*$filter*" $name]} {
            continue
        }

        lappend lines [FormatDfLine $name [DictGet $section path ""] [dict merge [dict create ok 1] $section]]
    }

    return [dict create ok 1 error "" lines $lines]
}

proc ::dZSbot::Modules::Site::ParseDfCacheLine {line} {

    set parts [split $line "\t"]
    if {[llength $parts] < 7} {
        return [dict create ok 0 error "expected 7 tab-separated fields"]
    }

    set error [lindex $parts 6]
    if {$error ne ""} {
        return [dict create ok 0 name [lindex $parts 1] path [lindex $parts 2] error $error]
    }

    return [dict create \
        ok 1 \
        timestamp [lindex $parts 0] \
        name [lindex $parts 1] \
        path [lindex $parts 2] \
        free_mb [lindex $parts 3] \
        used_mb [lindex $parts 4] \
        total_mb [lindex $parts 5] \
        error ""]
}

proc ::dZSbot::Modules::Site::CmdBw {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan]

    if {![::dZSbot::Config::Get site.commands.bw.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: command is disabled."
        return
    }

    set sample [TransferSample]
    if {![dict get $sample available]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: unavailable ([dict get $sample error])."
        return
    }

    set active [dict get $sample active]
    set total [dict get $sample total]
    set speed [FormatSpeed [dict get $sample speed]]
    set lines [dict get $sample lines]
    set type [DictGet $sample type "transfers"]

    if {[dict exists $sample summary]} {
        ::dZSbot::Commands::Reply $nick $replyTarget [dict get $sample summary]
    } elseif {$type eq "site"} {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: site status"
    } else {
        ::dZSbot::Commands::Reply $nick $replyTarget "BW: $active active / $total online | $speed"
    }
    foreach line $lines {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
}

proc ::dZSbot::Modules::Site::ReplyTarget {nick chan} {

    set target [string tolower [::dZSbot::Config::Get site.commands.reply_target "channel"]]
    if {$target in {private privmsg pm query nick user} && $nick ne ""} {
        return $nick
    }

    return $chan
}

proc ::dZSbot::Modules::Site::DiskFree {path} {

    if {![file exists $path]} {
        return [dict create ok 0 error "path not found: $path"]
    }

    EnsureExecTempDir

    set psPath [PowerShellPath $path]
    set escapedPath [PowerShellSingleQuote $psPath]
    set script [string map [list @@PATH@@ $escapedPath] {
            $p = '@@PATH@@'
            $item = Get-Item -LiteralPath $p -ErrorAction Stop
            $drive = [System.IO.DriveInfo]::new($item.PSDrive.Root)
            $free = [int64]($drive.AvailableFreeSpace / 1MB)
            $total = [int64]($drive.TotalSize / 1MB)
            $used = [int64](($drive.TotalSize - $drive.AvailableFreeSpace) / 1MB)
            [Console]::Out.WriteLine("$free|$used|$total")
        }]
    set command [list powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass \
        -Command $script]

    if {[catch {set output [exec {*}$command 2>@1]} error]} {
        return [dict create ok 0 error $error]
    }

    set parts [split [string trim $output] "|"]
    if {[llength $parts] < 3} {
        return [dict create ok 0 error "invalid disk output"]
    }

    return [dict create \
        ok 1 \
        free_mb [lindex $parts 0] \
        used_mb [lindex $parts 1] \
        total_mb [lindex $parts 2]]
}

proc ::dZSbot::Modules::Site::EnsureExecTempDir {} {

    set tempDir [file join $::dZSbot::Root runtime tmp]
    if {![file isdirectory $tempDir]} {
        file mkdir $tempDir
    }

    set normalized [file normalize $tempDir]
    set ::env(TMP) $normalized
    set ::env(TEMP) $normalized
    set ::env(TMPDIR) $normalized
}

proc ::dZSbot::Modules::Site::PowerShellPath {path} {

    set normalized [file normalize $path]
    if {[regexp {^[A-Za-z]:[/\\]} $normalized] || [string match "\\\\*" $normalized]} {
        return $normalized
    }

    set cygpath [::dZSbot::Config::Get site.commands.cygpath "C:/cygwin64/bin/cygpath.exe"]
    if {![file exists $cygpath]} {
        set cygpath "cygpath"
    }

    if {[catch {set converted [exec $cygpath -aw $normalized]}]} {
        return $normalized
    }

    return [string trim $converted]
}

proc ::dZSbot::Modules::Site::PowerShellSingleQuote {value} {

    return [string map [list "'" "''"] $value]
}

proc ::dZSbot::Modules::Site::FormatDfLine {name path result} {

    if {![dict get $result ok]} {
        return "DF: $name | ERROR | [dict get $result error]"
    }

    set free [dict get $result free_mb]
    set used [dict get $result used_mb]
    set total [dict get $result total_mb]
    set pct "N/A"

    if {[string is double -strict $total] && $total > 0} {
        set pct [format "%.1f%% free" [expr {($free * 100.0) / $total}]]
    }

    return "DF: $name | free [FormatBytesMb $free] / total [FormatBytesMb $total] | used [FormatBytesMb $used] | $pct"
}

proc ::dZSbot::Modules::Site::TransferSample {} {

    set source [string tolower [::dZSbot::Config::Get site.commands.bw.source "cache"]]

    if {$source in {auto fluxftp api}} {
        set sample [FluxFtpTransferSample]
        if {[dict get $sample available]} {
            return $sample
        }
        if {$source ni {auto} && [BwFallbackEnabled]} {
            set fallback [CacheTransferSample]
            if {[dict get $fallback available]} {
                return $fallback
            }
            dict set sample error "[dict get $sample error]; fallback failed: [dict get $fallback error]"
        }
        if {$source ne "auto"} {
            return $sample
        }
    }

    if {$source in {auto cache file status}} {
        set sample [CacheTransferSample]
        if {[dict get $sample available] || $source ne "auto"} {
            return $sample
        }
    }

    if {$source in {auto ioftpd local} && [llength [info commands ::ioftpd]]} {
        set sample [IoFtpdWhoSample]
        if {[dict get $sample available] || $source ne "auto"} {
            return $sample
        }
    }

    if {$source in {ftps ftp site}} {
        set sample [SiteCommandSample]
        if {[dict get $sample available] || $source ne "auto"} {
            return $sample
        }
    }

    return [dict create available 0 total 0 active 0 speed 0 lines {} error "no usable BW source" type none]
}

proc ::dZSbot::Modules::Site::FluxFtpAvailable {} {

    if {![llength [info commands ::dZSbot::Adapter::FluxFTP::Enabled]]} {
        return 0
    }

    if {![::dZSbot::Adapter::FluxFTP::Enabled]} {
        return 0
    }

    return 1
}

proc ::dZSbot::Modules::Site::DfFallbackEnabled {} {

    set fallback [string tolower [::dZSbot::Config::Get site.commands.df.fallback "cache"]]
    return [expr {$fallback in {cache file status}}]
}

proc ::dZSbot::Modules::Site::BwFallbackEnabled {} {

    set fallback [string tolower [::dZSbot::Config::Get site.commands.bw.fallback "cache"]]
    return [expr {$fallback in {cache file status}}]
}

proc ::dZSbot::Modules::Site::FluxFtpTransferSample {} {

    if {![FluxFtpAvailable]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "FluxFTP adapter unavailable" type fluxftp]
    }

    if {[catch {set result [::dZSbot::Adapter::FluxFTP::Bandwidth]} error]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error type fluxftp]
    }
    if {![dict get $result ok]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error [DictGet $result error "FluxFTP bandwidth failed"] type fluxftp]
    }

    set uploadCount [DictGet $result upload_count 0]
    set downloadCount [DictGet $result download_count 0]
    set transferCount [DictGet $result transfer_count 0]
    set idleCount [DictGet $result idle_count 0]
    set uploadSpeed [DictGet $result upload_speed_kbps 0]
    set downloadSpeed [DictGet $result download_speed_kbps 0]
    set transferSpeed [DictGet $result transfer_speed_kbps 0]
    set totalSpeed [DictGet $result total_speed_kbps [expr {$uploadSpeed + $downloadSpeed}]]
    set active [expr {$uploadCount + $downloadCount + $transferCount}]
    set total [expr {$active + $idleCount}]
    set showIdle [::dZSbot::Config::Get site.commands.bw.show_idle 0]
    set lines {}

    foreach transfer [DictGet $result transfers {}] {
        set direction [DictGet $transfer direction "unknown"]
        set speed [DictGet $transfer speed_kbps 0]
        if {($direction eq "idle" || $speed <= 0) && !$showIdle} {
            continue
        }

        lappend lines [FormatFluxFtpTransferLine $transfer]
    }

    set summary "BW: UP $uploadCount @ [FormatSpeed $uploadSpeed] | DN $downloadCount @ [FormatSpeed $downloadSpeed]"
    if {$transferCount > 0} {
        append summary " | XFER $transferCount @ [FormatSpeed $transferSpeed]"
    }
    append summary " | idle $idleCount | total [FormatSpeed $totalSpeed]"

    return [dict create \
        available 1 \
        total $total \
        active $active \
        speed $totalSpeed \
        lines [LimitLines $lines] \
        summary $summary \
        error "" \
        type fluxftp]
}

proc ::dZSbot::Modules::Site::CacheTransferSample {} {

    set path [::dZSbot::Config::Get site.commands.bw.cache_file ""]
    if {$path eq ""} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "site.commands.bw.cache_file not configured" type cache]
    }
    if {![file exists $path]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "BW cache file not found: $path" type cache]
    }

    set maxAge [::dZSbot::Config::Get site.commands.bw.cache_max_age_seconds 15]
    if {![string is integer -strict $maxAge] || $maxAge < 1} {
        set maxAge 15
    }

    set age [expr {[clock seconds] - [file mtime $path]}]
    if {$age > $maxAge} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "BW cache is stale (${age}s old)" type cache]
    }

    if {[catch {
        set fh [open $path r]
        fconfigure $fh -encoding utf-8 -translation lf
        set content [read $fh]
        close $fh
    } error]} {
        catch {close $fh}
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error type cache]
    }

    set total 0
    set active 0
    set idle 0
    set uploadCount 0
    set downloadCount 0
    set uploadSpeed 0.0
    set downloadSpeed 0.0
    set unknownSpeed 0.0
    set lines {}
    set showIdle [::dZSbot::Config::Get site.commands.bw.show_idle 0]

    foreach rawLine [split $content "\n"] {
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq "" || [string match "#*" [string trimleft $rawLine]]} {
            continue
        }

        set entry [ParseBwCacheLine $rawLine]
        if {![dict get $entry ok]} {
            continue
        }

        incr total
        set direction [dict get $entry direction]
        set speed [dict get $entry speed]
        set isIdle [expr {$direction eq "idle" || (![string is double -strict $speed] || $speed <= 0)}]

        if {$isIdle} {
            incr idle
        } else {
            incr active
        }

        if {$direction eq "upload"} {
            incr uploadCount
            if {[string is double -strict $speed]} {
                set uploadSpeed [expr {$uploadSpeed + $speed}]
            }
        } elseif {$direction eq "download"} {
            incr downloadCount
            if {[string is double -strict $speed]} {
                set downloadSpeed [expr {$downloadSpeed + $speed}]
            }
        } elseif {[string is double -strict $speed]} {
            set unknownSpeed [expr {$unknownSpeed + $speed}]
        }

        if {!$isIdle || $showIdle} {
            lappend lines [FormatCacheTransferLine $entry]
        }
    }

    set totalSpeed [expr {$uploadSpeed + $downloadSpeed + $unknownSpeed}]
    set summary "BW: UP $uploadCount @ [FormatSpeed $uploadSpeed] | DN $downloadCount @ [FormatSpeed $downloadSpeed] | idle $idle | total [FormatSpeed $totalSpeed]"

    return [dict create \
        available 1 \
        total $total \
        active $active \
        speed $totalSpeed \
        lines [LimitLines $lines] \
        summary $summary \
        error "" \
        type cache]
}

proc ::dZSbot::Modules::Site::ParseBwCacheLine {line} {

    set parts [split $line "\t"]
    if {[llength $parts] < 7} {
        return [dict create ok 0 error "expected 7 tab-separated fields"]
    }

    set direction [NormalizeDirection [lindex $parts 1]]
    set speed [lindex $parts 4]
    if {![string is double -strict $speed]} {
        set speed 0
    }

    return [dict create \
        ok 1 \
        timestamp [lindex $parts 0] \
        direction $direction \
        user [lindex $parts 2] \
        group [lindex $parts 3] \
        speed $speed \
        vpath [lindex $parts 5] \
        datapath [lindex $parts 6] \
        status [lindex $parts 7]]
}

proc ::dZSbot::Modules::Site::NormalizeDirection {value} {

    set direction [string tolower [string trim $value]]
    if {$direction in {up upload uploading stor}} {
        return "upload"
    }
    if {$direction in {dn down download downloading retr fxp}} {
        return "download"
    }
    if {$direction in {idle none}} {
        return "idle"
    }

    return "unknown"
}

proc ::dZSbot::Modules::Site::IoFtpdWhoSample {} {

    set messageWindow [::dZSbot::Config::Get site.ioftpd.message_window "ioFTPD::MessageWindow"]
    if {[catch {
        set online [::ioftpd who $messageWindow "status user group speed vpath"]
    } error]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error type ioftpd]
    }

    set total 0
    set active 0
    set speed 0.0
    set lines {}
    set showIdle [::dZSbot::Config::Get site.commands.bw.show_idle 0]

    foreach entry $online {
        foreach {status user group userSpeed vpath} $entry {
            break
        }

        incr total
        set isActive [expr {$status eq "1"}]
        if {$isActive} {
            incr active
            if {[string is double -strict $userSpeed]} {
                set speed [expr {$speed + $userSpeed}]
            }
        }

        if {$isActive || $showIdle} {
            lappend lines [FormatTransferLine $status $user $group $userSpeed $vpath]
        }
    }

    return [dict create available 1 total $total active $active speed $speed lines $lines error "" type transfers]
}

proc ::dZSbot::Modules::Site::SiteCommandSample {} {

    set user [::dZSbot::Config::Get site.user ""]
    set password [::dZSbot::Config::Get site.password ""]

    if {$user eq "" || $password eq ""} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "site.user/site.password not configured" type site]
    }

    set commands [::dZSbot::Config::Get site.commands.bw.site_commands {"TRAFFIC" "STATS"}]
    set output {}

    foreach command $commands {
        set result [FtpSiteCommand $command]
        if {[dict get $result ok]} {
            foreach line [ParseSiteCommandLines [dict get $result lines]] {
                lappend output "BW: $line"
            }
            if {[llength $output]} {
                return [dict create available 1 total 0 active 0 speed 0 lines [LimitLines $output] error "" type site]
            }
        } else {
            ::dZSbot::Logger::Warn "SITE $command failed: [dict get $result error]"
        }
    }

    return [dict create available 0 total 0 active 0 speed 0 lines {} error "SITE traffic commands returned no usable output" type site]
}

proc ::dZSbot::Modules::Site::FtpSiteCommand {siteCommand} {

    set host [::dZSbot::Config::Get site.host "127.0.0.1"]
    set port [::dZSbot::Config::Get site.port 5420]
    set user [::dZSbot::Config::Get site.user ""]
    set password [::dZSbot::Config::Get site.password ""]
    set transport [string tolower [::dZSbot::Config::Get site.command_transport "ftps"]]
    set timeout [::dZSbot::Config::Get site.commands.bw.timeout_ms 10000]
    set sock ""

    if {[catch {
        if {$transport eq "ftps"} {
            package require tls
        }

        set sock [socket $host $port]
        ConfigureControlSocket $sock
        set responses [list [FtpReadResponse $sock $timeout]]

        if {$transport eq "ftps"} {
            FtpWrite $sock "AUTH TLS"
            lappend responses [FtpReadResponse $sock $timeout]
            ::tls::import $sock -require 0
            ConfigureControlSocket $sock
            FtpWrite $sock "PBSZ 0"
            lappend responses [FtpReadResponse $sock $timeout]
            FtpWrite $sock "PROT P"
            lappend responses [FtpReadResponse $sock $timeout]
        }

        FtpWrite $sock "USER $user"
        lappend responses [FtpReadResponse $sock $timeout]
        FtpWrite $sock "PASS $password"
        lappend responses [FtpReadResponse $sock $timeout]
        FtpWrite $sock "SITE $siteCommand"
        lappend responses [FtpReadResponse $sock $timeout]
        catch {FtpWrite $sock "QUIT"}
        catch {FtpReadResponse $sock 1000}
        close $sock
        set sock ""
    } error]} {
        catch {close $sock}
        return [dict create ok 0 error $error lines {}]
    }

    set lines {}
    foreach response $responses {
        foreach line [dict get $response lines] {
            lappend lines $line
        }
    }

    return [dict create ok 1 lines $lines]
}

proc ::dZSbot::Modules::Site::ConfigureControlSocket {sock} {

    fconfigure $sock -blocking 1 -buffering line -translation crlf -encoding iso8859-1
}

proc ::dZSbot::Modules::Site::FtpWrite {sock command} {

    puts $sock $command
    flush $sock
}

proc ::dZSbot::Modules::Site::FtpReadResponse {sock timeoutMs} {

    set deadline [expr {[clock milliseconds] + $timeoutMs}]
    set lines {}
    set code ""

    while {[clock milliseconds] < $deadline} {
        if {[eof $sock]} {
            break
        }

        if {[catch {set line [gets $sock]} error]} {
            error $error
        }
        if {$line eq "" && [eof $sock]} {
            break
        }

        set line [string trimright $line "\r"]
        lappend lines $line

        if {[regexp {^([0-9][0-9][0-9])[- ]} $line -> currentCode]} {
            if {$code eq ""} {
                set code $currentCode
            }
            if {[regexp "^$code " $line]} {
                return [dict create code $code lines $lines]
            }
        } elseif {[llength $lines] > 0 && $code eq ""} {
            return [dict create code "" lines $lines]
        }
    }

    if {[llength $lines]} {
        return [dict create code $code lines $lines]
    }

    error "FTP response timed out"
}

proc ::dZSbot::Modules::Site::ParseSiteCommandLines {lines} {

    set result {}
    foreach line $lines {
        set clean [string trim $line]
        regsub {^[0-9][0-9][0-9][- ]} $clean "" clean
        set clean [string trim $clean " \t|"]

        if {$clean eq ""} {
            continue
        }
        if {[regexp -nocase {^(user|pass|auth tls|pbsz|prot|quit|site)} $clean]} {
            continue
        }
        if {[regexp {^[0-9][0-9][0-9]$} $clean]} {
            continue
        }

        lappend result $clean
    }

    return $result
}

proc ::dZSbot::Modules::Site::LimitLines {lines} {

    set max [::dZSbot::Config::Get site.commands.bw.max_lines 6]
    if {![string is integer -strict $max] || $max <= 0} {
        return $lines
    }

    return [lrange $lines 0 [expr {$max - 1}]]
}

proc ::dZSbot::Modules::Site::FormatTransferLine {status user group speed vpath} {

    set label [expr {$status eq "1" ? "XFER" : "IDLE"}]
    return "BW: $label | $user/$group | [FormatSpeed $speed] | $vpath"
}

proc ::dZSbot::Modules::Site::FormatCacheTransferLine {entry} {

    set direction [dict get $entry direction]
    set label [string toupper $direction]
    if {$label eq "UPLOAD"} {
        set label "UP"
    } elseif {$label eq "DOWNLOAD"} {
        set label "DN"
    } elseif {$label eq "TRANSFER"} {
        set label "XFER"
    } elseif {$label eq "UNKNOWN"} {
        set label "XFER"
    }

    set user [dict get $entry user]
    set group [dict get $entry group]
    set account $user
    if {$group ne ""} {
        set account "$user/$group"
    }

    set path [dict get $entry vpath]
    if {$path eq ""} {
        set path [dict get $entry datapath]
    }

    return "BW: $label | $account | [FormatSpeed [dict get $entry speed]] | $path"
}

proc ::dZSbot::Modules::Site::FormatFluxFtpTransferLine {entry} {

    set direction [DictGet $entry direction "unknown"]
    set label [string toupper $direction]
    if {$label eq "UPLOAD"} {
        set label "UP"
    } elseif {$label eq "DOWNLOAD"} {
        set label "DN"
    } elseif {$label eq "UNKNOWN"} {
        set label "XFER"
    }

    set user [DictGet $entry user ""]
    set group [DictGet $entry group ""]
    set account $user
    if {$group ne ""} {
        set account "$user/$group"
    }
    if {$account eq ""} {
        set account "unknown"
    }

    return "BW: $label | $account | [FormatSpeed [DictGet $entry speed_kbps 0]] | [DictGet $entry path ""]"
}

proc ::dZSbot::Modules::Site::DictGet {dictValue key default} {

    if {[catch {dict exists $dictValue $key} exists] || !$exists} {
        return $default
    }

    return [dict get $dictValue $key]
}

proc ::dZSbot::Modules::Site::FormatBytesMb {value} {

    if {![string is double -strict $value]} {
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

proc ::dZSbot::Modules::Site::FormatSpeed {value} {

    if {![string is double -strict $value]} {
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

::dZSbot::Commands::Register site !df ::dZSbot::Modules::Site::CmdDf "Show site disk free"
::dZSbot::Commands::Register site !bw ::dZSbot::Modules::Site::CmdBw "Show site transfer bandwidth"

::dZSbot::ModuleManager::Register site [dict create \
    version $::dZSbot::Modules::Site::Version \
    description "Site status commands" \
    commands [::dZSbot::Commands::List site]]
