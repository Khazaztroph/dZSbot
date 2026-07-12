###############################################################################
#
# dZSbot 2.0
#
# Module      : Health
# Description : Runtime health registry and heartbeat writer.
#
###############################################################################

namespace eval ::dZSbot::Health {

    variable Components
    array set Components {}
}

proc ::dZSbot::Health::Set {component status {message ""}} {

    variable Components

    set normalized [string tolower $status]
    set Components($component) [dict create \
        status $normalized \
        message $message \
        updated [clock seconds]]

    return $Components($component)
}

proc ::dZSbot::Health::Get {component} {

    variable Components

    if {[info exists Components($component)]} {
        return $Components($component)
    }

    return [dict create status unknown message "" updated 0]
}

proc ::dZSbot::Health::Summary {} {

    variable Components

    set overall ok
    set result {}

    foreach component [lsort [array names Components]] {
        set entry $Components($component)
        dict set result components $component $entry

        if {[dict get $entry status] in {error critical failed}} {
            set overall error
        } elseif {[dict get $entry status] eq "warn" && $overall eq "ok"} {
            set overall warn
        }
    }

    dict set result overall $overall
    dict set result updated [clock seconds]

    return $result
}

proc ::dZSbot::Health::WriteHeartbeat {{path ""}} {

    if {$path eq ""} {
        set path [file join $::dZSbot::Root runtime heartbeat.json]
    }

    file mkdir [file dirname $path]

    set summary [Summary]
    set handle [open $path w]
    puts $handle [_JsonObject $summary]
    close $handle

    return $path
}

proc ::dZSbot::Health::_JsonObject {value} {

    if {[catch {dict size $value}]} {
        return [_JsonString $value]
    }

    set parts {}
    dict for {key item} $value {
        if {[catch {dict size $item}]} {
            if {[string is integer -strict $item]} {
                set encoded $item
            } else {
                set encoded [_JsonString $item]
            }
        } else {
            set encoded [_JsonObject $item]
        }
        lappend parts "[_JsonString $key]: $encoded"
    }

    return "\{[join $parts {, }]\}"
}

proc ::dZSbot::Health::_JsonString {value} {

    set escaped [string map [list "\\" "\\\\" "\"" "\\\"" "\n" "\\n" "\r" "\\r" "\t" "\\t"] $value]
    return "\"$escaped\""
}
