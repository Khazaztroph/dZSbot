###############################################################################
#
# dZSbot 2.0
#
# Module      : Logger
# Description : Core logger with counters and Eggdrop/tclsh fallback.
#
###############################################################################

namespace eval ::dZSbot::Logger {

    variable Initialized 0
    variable DebugEnabled 0
    variable Counters
    array set Counters {
        info 0
        warn 0
        error 0
        debug 0
    }
}

proc ::dZSbot::Logger::Initialize {} {

    variable Initialized
    variable Counters

    if {$Initialized} {
        return
    }

    foreach level {info warn error debug} {
        set Counters($level) 0
    }

    set Initialized 1
}

proc ::dZSbot::Logger::DebugMode {enabled} {

    variable DebugEnabled
    set DebugEnabled [expr {$enabled ? 1 : 0}]
}

proc ::dZSbot::Logger::Counter {level} {

    variable Counters
    set key [string tolower $level]

    if {![info exists Counters($key)]} {
        return 0
    }

    return $Counters($key)
}

proc ::dZSbot::Logger::Info {message} {

    _Log info INFO $message
}

proc ::dZSbot::Logger::Warn {message} {

    _Log warn WARN $message
}

proc ::dZSbot::Logger::Error {message} {

    _Log error ERROR $message
}

proc ::dZSbot::Logger::Debug {message} {

    variable DebugEnabled

    if {!$DebugEnabled} {
        return
    }

    _Log debug DEBUG $message
}

proc ::dZSbot::Logger::Plain {message} {

    foreach line [NormalizeLines $message] {
        if {[llength [info commands ::putlog]]} {
            ::putlog $line
        } else {
            puts $line
        }
    }
}

proc ::dZSbot::Logger::_Log {counter level message} {

    variable Initialized
    variable Counters

    if {!$Initialized} {
        Initialize
    }

    incr Counters($counter)
    _Write $level $message
}

proc ::dZSbot::Logger::_Write {level message} {

    set line [format {[%-5s] %s} $level $message]

    foreach outputLine [NormalizeLines $line] {
        if {[llength [info commands ::putlog]]} {
            ::putlog $outputLine
        } else {
            puts $outputLine
        }
    }
}

proc ::dZSbot::Logger::NormalizeLines {message} {

    set normalized [string map [list "\r\n" "\n" "\r" "\n"] $message]
    return [split $normalized "\n"]
}
