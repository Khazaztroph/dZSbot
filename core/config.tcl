###############################################################################
#
# dZSbot 2.0
#
# Module      : Config
# Description : Small runtime configuration store.
#
###############################################################################

namespace eval ::dZSbot::Config {

    variable Values
    array set Values {}
}

proc ::dZSbot::Config::Set {key value} {

    variable Values
    set Values($key) $value
    return $value
}

proc ::dZSbot::Config::Get {key {default ""}} {

    variable Values

    if {[info exists Values($key)]} {
        return $Values($key)
    }

    return $default
}

proc ::dZSbot::Config::Exists {key} {

    variable Values
    return [info exists Values($key)]
}

proc ::dZSbot::Config::Load {path {quiet 0}} {

    if {![file exists $path]} {
        if {!$quiet} {
            ::dZSbot::Logger::Warn "Config file not found: $path"
        }
        return 0
    }

    if {[catch {uplevel #0 [list source $path]} error options]} {
        ::dZSbot::Logger::Error "Failed to load config '$path': $error"
        return 0
    }

    if {!$quiet} {
        ::dZSbot::Logger::Info "Loaded config: $path"
    }

    return 1
}

proc ::dZSbot::Config::Snapshot {} {

    variable Values
    return [array get Values]
}
