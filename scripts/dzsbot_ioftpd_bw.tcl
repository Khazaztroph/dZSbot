# dZSbot ioFTPD bandwidth exporter.
#
# Install this script on the ioFTPD side and run it from ioFTPD's Tcl
# environment. It writes a small tab-separated cache that Eggdrop/dZSbot can
# read with the !bw command.
#
# Example:
#   TCL ..\scripts\dZSbot\dzsbot_ioftpd_bw.tcl BW C:/ioFTPD/logs/dzsbot-bw.tsv

proc dzsbot_bw_clean {value} {
    return [string map [list "\t" " " "\r" " " "\n" " "] $value]
}

proc dzsbot_bw_direction {status virtualPath dataPath speed} {
    switch -- $status {
        1 { return "download" }
        2 { return "upload" }
        0 -
        3 { return "idle" }
    }

    if {![string is double -strict $speed] || $speed <= 0} {
        return "idle"
    }

    return "unknown"
}

proc dzsbot_bw_user {userId} {
    if {[catch {set userName [resolve uid $userId]}]} {
        return $userId
    }
    return $userName
}

proc dzsbot_write_bw_cache {{outputPath "C:/ioFTPD/logs/dzsbot-bw.tsv"}} {
    set now [clock seconds]
    set dir [file dirname $outputPath]
    if {$dir ne "" && ![file isdirectory $dir]} {
        file mkdir $dir
    }

    set tmpPath "$outputPath.tmp"
    set fh [open $tmpPath w]
    fconfigure $fh -encoding utf-8 -translation lf
    puts $fh "# dZSbot-bw-v1\t$now"

    if {[client who init "CID" "UID" "STATUS" "TIMEIDLE" "TRANSFERSPEED" "VIRTUALPATH" "VIRTUALDATAPATH"] != 0} {
        puts $fh "# error\tclient who init failed"
        close $fh
        file rename -force $tmpPath $outputPath
        return 1
    }

    while {[set row [client who fetch]] ne ""} {
        foreach {clientId userId status idle speed virtualPath dataPath} $row {
            break
        }

        set user [dzsbot_bw_user $userId]
        set group ""
        set direction [dzsbot_bw_direction $status $virtualPath $dataPath $speed]
        puts $fh [join [list \
            $now \
            [dzsbot_bw_clean $direction] \
            [dzsbot_bw_clean $user] \
            [dzsbot_bw_clean $group] \
            [dzsbot_bw_clean $speed] \
            [dzsbot_bw_clean $virtualPath] \
            [dzsbot_bw_clean $dataPath] \
            [dzsbot_bw_clean $status]] "\t"]
    }

    catch {client who free}
    close $fh
    file rename -force $tmpPath $outputPath
    return 0
}

proc dzsbot_bw_log_error {message} {
    set errorPath "C:/ioFTPD/logs/dzsbot-bw-error.log"
    if {[catch {
        set fh [open $errorPath a]
        fconfigure $fh -encoding utf-8 -translation lf
        puts $fh "[clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}] $message"
        close $fh
    }]} {
        catch {close $fh}
    }
}

proc dzsbot_bw_main {argString} {
    set action [string toupper [lindex $argString 0]]
    set outputPath [lindex $argString 1]
    if {$outputPath eq ""} {
        set outputPath "C:/ioFTPD/logs/dzsbot-bw.tsv"
    }

    switch -- $action {
        BW -
        WRITE -
        STATUS {
            return [dzsbot_write_bw_cache $outputPath]
        }
        default {
            return [dzsbot_write_bw_cache $outputPath]
        }
    }
}

if {[catch {
    dzsbot_bw_main [expr {[info exists args] ? $args : ""}]
} error options]} {
    dzsbot_bw_log_error "$error | $options"
    catch {iputs "dZSbot BW error: $error"}
}
