namespace eval ::dZSbot::Modules::Site {

    variable Version "0.1.0"
}

proc ::dZSbot::Modules::Site::CmdDf {nick host hand chan text} {

    set replyTarget [ReplyTarget $nick $chan]

    if {![::dZSbot::Config::Get site.commands.df.enabled 1]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: command is disabled."
        return
    }

    set sections [::dZSbot::Config::Get site.df.sections {}]
    if {![llength $sections]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: no sections configured. Set site.df.sections in config/modules/site.conf."
        return
    }

    set filter [string toupper [string trim $text]]
    set lines {}

    foreach section $sections {
        if {[llength $section] < 2} {
            continue
        }

        set name [string toupper [lindex $section 0]]
        set path [lindex $section 1]
        if {$filter ne "" && ![string match "*$filter*" $name]} {
            continue
        }

        lappend lines [FormatDfLine $name $path [DiskFree $path]]
    }

    if {![llength $lines]} {
        ::dZSbot::Commands::Reply $nick $replyTarget "DF: no configured section matched '$text'."
        return
    }

    foreach line $lines {
        ::dZSbot::Commands::Reply $nick $replyTarget $line
    }
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

    ::dZSbot::Commands::Reply $nick $replyTarget "BW: $active active / $total online | $speed"
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

    if {[catch {set output [exec {*}$command]} error]} {
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

    if {![llength [info commands ::ioftpd]]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error "ioftpd command unavailable"]
    }

    set messageWindow [::dZSbot::Config::Get site.ioftpd.message_window "ioFTPD::MessageWindow"]
    if {[catch {
        set online [::ioftpd who $messageWindow "status user group speed vpath"]
    } error]} {
        return [dict create available 0 total 0 active 0 speed 0 lines {} error $error]
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

    return [dict create available 1 total $total active $active speed $speed lines $lines error ""]
}

proc ::dZSbot::Modules::Site::FormatTransferLine {status user group speed vpath} {

    set label [expr {$status eq "1" ? "XFER" : "IDLE"}]
    return "BW: $label | $user/$group | [FormatSpeed $speed] | $vpath"
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
