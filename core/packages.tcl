###############################################################################
#
# dZSbot 2.0
#
# Module      : Packages
# Description : Runtime dependency checks.
#
###############################################################################

namespace eval ::dZSbot::Packages {

    variable Loaded
    variable HttpsRegistered 0
    array set Loaded {}
}

proc ::dZSbot::Packages::CheckTcl {{quiet 0}} {

    set required $::dZSbot::TclRequired

    if {[package vcompare [info patchlevel] $required] < 0} {
        error "Tcl $required or newer is required, current version is [info patchlevel]"
    }

    if {!$quiet} {
        ::dZSbot::Logger::Info "Tcl runtime OK: [info patchlevel]"
    }

    return 1
}

proc ::dZSbot::Packages::Require {name {version ""}} {

    variable Loaded

    if {$version eq ""} {
        set loadedVersion [package require $name]
    } else {
        set loadedVersion [package require $name $version]
    }

    set Loaded($name) $loadedVersion
    ::dZSbot::Logger::Debug "Package loaded: $name $loadedVersion"

    return $loadedVersion
}

proc ::dZSbot::Packages::Loaded {} {

    variable Loaded
    return [array get Loaded]
}

proc ::dZSbot::Packages::EnsureHttps {{verify ""}} {

    variable HttpsRegistered

    Require http
    Require tls

    if {$verify eq ""} {
        if {[llength [info commands ::dZSbot::Config::Get]]} {
            set verify [::dZSbot::Config::Get api.tls.verify 0]
        } else {
            set verify 0
        }
    }

    ::http::register https 443 [list ::dZSbot::Packages::HttpsSocket $verify]
    set HttpsRegistered 1

    return 1
}

proc ::dZSbot::Packages::HttpsSocket {verify args} {

    set socketArgs {}
    set count [llength $args]

    for {set index 0} {$index < $count} {incr index} {
        set arg [lindex $args $index]
        if {$arg eq "-async"} {
            continue
        }
        lappend socketArgs $arg
    }

    return [::tls::socket -autoservername 1 -require $verify {*}$socketArgs]
}
