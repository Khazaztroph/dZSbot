###############################################################################
#
# dZSbot 2.0
#
# Module      : Metrics
# Description : Lightweight runtime metrics.
#
###############################################################################

namespace eval ::dZSbot::Metrics {

    variable Values
    array set Values {}
}

proc ::dZSbot::Metrics::Set {name value} {

    variable Values
    set Values($name) $value
    return $value
}

proc ::dZSbot::Metrics::Increment {name {amount 1}} {

    variable Values

    if {![info exists Values($name)]} {
        set Values($name) 0
    }

    incr Values($name) $amount
    return $Values($name)
}

proc ::dZSbot::Metrics::Get {name {default 0}} {

    variable Values

    if {[info exists Values($name)]} {
        return $Values($name)
    }

    return $default
}

proc ::dZSbot::Metrics::Snapshot {} {

    variable Values
    return [array get Values]
}
