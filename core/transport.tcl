###############################################################################
#
# dZSbot 2.0
#
# Module      : Transport
# Description : Internal event bus for core and modules.
#
###############################################################################

namespace eval ::dZSbot::Transport {

    variable Subscribers
    array set Subscribers {}
}

proc ::dZSbot::Transport::Subscribe {event callback} {

    variable Subscribers

    if {![info exists Subscribers($event)]} {
        set Subscribers($event) {}
    }

    lappend Subscribers($event) $callback
    ::dZSbot::Logger::Debug "Subscribed '$callback' to '$event'"

    return $callback
}

proc ::dZSbot::Transport::Publish {event payload} {

    variable Subscribers

    ::dZSbot::Metrics::Increment "transport.events"

    if {![info exists Subscribers($event)]} {
        return 0
    }

    set delivered 0
    foreach callback $Subscribers($event) {
        if {[catch {uplevel #0 [list {*}$callback $event $payload]} error options]} {
            ::dZSbot::Metrics::Increment "transport.errors"
            ::dZSbot::Logger::Error "Transport callback failed for '$event': $error"
            continue
        }

        incr delivered
    }

    return $delivered
}

proc ::dZSbot::Transport::Subscribers {{event ""}} {

    variable Subscribers

    if {$event ne ""} {
        if {[info exists Subscribers($event)]} {
            return $Subscribers($event)
        }
        return {}
    }

    return [array get Subscribers]
}
