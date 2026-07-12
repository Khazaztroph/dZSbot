###############################################################################
#
# dZSbot 2.0
#
# Module      : Commands
# Description : Eggdrop command compatibility layer.
#
###############################################################################

namespace eval ::dZSbot::Commands {

    variable Commands
    array set Commands {}
}

proc ::dZSbot::Commands::Register {module command callback {description ""}} {

    variable Commands

    set normalized [Normalize $command]
    set Commands($normalized) [dict create \
        module $module \
        command $normalized \
        callback $callback \
        description $description]

    if {[llength [info commands ::bind]]} {
        ::bind pub - $normalized $callback
    }

    ::dZSbot::Logger::Debug "Registered command $normalized for $module"
    return $normalized
}

proc ::dZSbot::Commands::Normalize {command} {

    if {[string index $command 0] ne "!"} {
        return "!$command"
    }

    return $command
}

proc ::dZSbot::Commands::Reply {nick chan message} {

    if {$chan ne "" && [llength [info commands ::putserv]]} {
        ::putserv "PRIVMSG $chan :$message"
        return
    }

    if {[llength [info commands ::puthelp]] && $chan ne ""} {
        ::puthelp "PRIVMSG $chan :$message"
        return
    }

    if {$chan ne ""} {
        ::dZSbot::Logger::Plain "<$chan> $message"
        return
    }

    ::dZSbot::Logger::Plain $message
}

proc ::dZSbot::Commands::Dispatch {command nick host hand chan text} {

    variable Commands
    set normalized [Normalize $command]

    if {![info exists Commands($normalized)]} {
        Reply $nick $chan "Unknown command: $normalized"
        return 0
    }

    set callback [dict get $Commands($normalized) callback]

    if {[catch {uplevel #0 [list $callback $nick $host $hand $chan $text]} error options]} {
        ::dZSbot::Logger::Error "Command $normalized failed: $error"
        Reply $nick $chan "Command failed: $normalized"
        return 0
    }

    return 1
}

proc ::dZSbot::Commands::List {{module ""}} {

    variable Commands
    set result {}

    foreach command [lsort [array names Commands]] {
        if {$module eq "" || [dict get $Commands($command) module] eq $module} {
            lappend result $command
        }
    }

    return $result
}
