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
    variable MaxIrcMessageLength 390
    variable PubmFallbackBound 0
    variable PublicLastKey ""
    variable PublicLastClock 0
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
        set handler [HandlerName $normalized]
        proc $handler {nick host hand chan text} [format {
            return [::dZSbot::Commands::PubInvoke %s %s $nick $host $hand $chan $text]
        } [list $normalized] [list $callback]]

        catch {::unbind pub - $normalized $callback}
        catch {::unbind pub - $normalized $handler}
        ::bind pub - $normalized $handler

        set uppercase [string toupper $normalized]
        if {$uppercase ne $normalized} {
            catch {::unbind pub - $uppercase $callback}
            catch {::unbind pub - $uppercase $handler}
            ::bind pub - $uppercase $handler
        }

        EnsurePubmFallback
    }

    ::dZSbot::Logger::Debug "Registered command $normalized for $module"
    return $normalized
}

proc ::dZSbot::Commands::HandlerName {command} {

    set mapped [string map [list "!" "bang_" "." "_" "-" "_" ":" "_"] $command]
    return "::dZSbot::Commands::PubHandler_$mapped"
}

proc ::dZSbot::Commands::Normalize {command} {

    set trimmed [string trim $command]
    if {[string index $trimmed 0] ne "!"} {
        set trimmed "!$trimmed"
    }

    return [string tolower $trimmed]
}

proc ::dZSbot::Commands::Reply {nick chan message} {

    set message [IrcSafeMessage $message]

    if {[llength [info commands ::puthelp]] && $chan ne ""} {
        ::puthelp "PRIVMSG $chan :$message"
        return
    }

    if {$chan ne "" && [llength [info commands ::putserv]]} {
        ::putserv "PRIVMSG $chan :$message"
        return
    }

    if {$chan ne ""} {
        ::dZSbot::Logger::Plain "<$chan> $message"
        return
    }

    ::dZSbot::Logger::Plain $message
}

proc ::dZSbot::Commands::EnsurePubmFallback {} {

    variable PubmFallbackBound

    if {$PubmFallbackBound} {
        return
    }
    if {![llength [info commands ::bind]]} {
        return
    }

    catch {::unbind pubm - * ::dZSbot::Commands::PubmFallback}
    ::bind pubm - * ::dZSbot::Commands::PubmFallback
    set PubmFallbackBound 1
}

proc ::dZSbot::Commands::PubInvoke {command callback nick host hand chan text} {

    MarkPublicCommand $nick $chan $command $text

    if {[catch {uplevel #0 [list $callback $nick $host $hand $chan $text]} error options]} {
        ::dZSbot::Logger::Error "Command $command failed: $error"
        Reply $nick $chan "Command failed: $command"
        return 0
    }

    return 1
}

proc ::dZSbot::Commands::PubmFallback {nick host hand chan text} {

    variable Commands

    set trimmed [string trimleft $text]
    if {$trimmed eq "" || [string index $trimmed 0] ne "!"} {
        return 0
    }

    set words [split $trimmed]
    set command [Normalize [lindex $words 0]]
    if {![info exists Commands($command)]} {
        return 0
    }

    set rest [join [lrange $words 1 end] " "]
    if {[RecentPublicCommand $nick $chan $command $rest]} {
        return 0
    }

    return [Dispatch $command $nick $host $hand $chan $rest]
}

proc ::dZSbot::Commands::MarkPublicCommand {nick chan command text} {

    variable PublicLastKey
    variable PublicLastClock

    set PublicLastKey [PublicCommandKey $nick $chan $command $text]
    set PublicLastClock [clock milliseconds]
}

proc ::dZSbot::Commands::RecentPublicCommand {nick chan command text} {

    variable PublicLastKey
    variable PublicLastClock

    set key [PublicCommandKey $nick $chan $command $text]
    set now [clock milliseconds]

    return [expr {$key eq $PublicLastKey && ($now - $PublicLastClock) < 1000}]
}

proc ::dZSbot::Commands::PublicCommandKey {nick chan command text} {

    return "[string tolower $nick]|[string tolower $chan]|[Normalize $command]|[string trim $text]"
}

proc ::dZSbot::Commands::IrcSafeMessage {message} {

    variable MaxIrcMessageLength

    set safe [string map [list "\r" " " "\n" " "] $message]
    set safe [string trim $safe]

    if {[string length $safe] > $MaxIrcMessageLength} {
        set safe "[string range $safe 0 [expr {$MaxIrcMessageLength - 4}]]..."
    }

    return $safe
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
