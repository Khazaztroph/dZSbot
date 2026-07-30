###############################################################################
#
# dZSbot 2.0
#
# Main Entry Point
#
###############################################################################

namespace eval ::dZSbot {

    variable Root
    variable StartupClock

    set Root [file normalize [file dirname [info script]]]
    set StartupClock [clock microseconds]
}

set ::auto_path [linsert $::auto_path 0 [file join $::dZSbot::Root lib]]
foreach ::dZSbot::LocalLib [glob -nocomplain -type d [file join $::dZSbot::Root lib *]] {
    set ::auto_path [linsert $::auto_path 0 $::dZSbot::LocalLib]
}
unset -nocomplain ::dZSbot::LocalLib

set ::dZSbot::UseOptTclLibs 1
set ::dZSbot::ExeName [string map [list "\\" "/"] [file normalize [info nameofexecutable]]]
if {[regexp {(^|/)bin/tclsh8\.6\.exe$} $::dZSbot::ExeName] && ![string match "*/opt/*" $::dZSbot::ExeName]} {
    set ::dZSbot::UseOptTclLibs 0
}

if {$::dZSbot::UseOptTclLibs} {
    foreach ::dZSbot::OptLib {
        /opt/tcl-8.6.18/lib
        /opt/tcl-8.6.18/lib/tdbc1.1.13
        /opt/tcl-8.6.18/lib/tdbcmysql1.1.13
        /opt/tcl8.6.18/lib
        /opt/tcl8.6.18/lib/tdbc1.1.13
        /opt/tcl8.6.18/lib/tdbcmysql1.1.13
        /opt/tcl-9.0.2/lib
        /opt/tcl-9.0.2/lib/tdbc1.1.11
        /opt/tcl-9.0.2/lib/tdbcmysql1.1.11
        /opt/tcl-9.0.2/lib/tdbc1.1.13
        /opt/tcl-9.0.2/lib/tdbcmysql1.1.13
        /opt/tcl9.0.2/lib
        /opt/tcl9.0.2/lib/tdbc1.1.11
        /opt/tcl9.0.2/lib/tdbcmysql1.1.11
        /opt/tcl9.0.2/lib/tdbc1.1.13
        /opt/tcl9.0.2/lib/tdbcmysql1.1.13
    } {
        if {[file isdirectory $::dZSbot::OptLib]} {
            set ::auto_path [linsert $::auto_path 0 $::dZSbot::OptLib]
        }
    }
}
unset -nocomplain ::dZSbot::UseOptTclLibs ::dZSbot::ExeName ::dZSbot::OptLib

source [file join $::dZSbot::Root core version.tcl]
source [file join $::dZSbot::Root core logger.tcl]
source [file join $::dZSbot::Root core packages.tcl]
source [file join $::dZSbot::Root core config.tcl]
source [file join $::dZSbot::Root core metrics.tcl]
source [file join $::dZSbot::Root core health.tcl]
source [file join $::dZSbot::Root core database.tcl]
source [file join $::dZSbot::Root core theme.tcl]
source [file join $::dZSbot::Root core commands.tcl]
source [file join $::dZSbot::Root core transport.tcl]
source [file join $::dZSbot::Root core siteadapter.tcl]
foreach ::dZSbot::AdapterFile [lsort [glob -nocomplain [file join $::dZSbot::Root core adapters *.tcl]]] {
    source $::dZSbot::AdapterFile
}
unset -nocomplain ::dZSbot::AdapterFile
source [file join $::dZSbot::Root core modulemanager.tcl]
source [file join $::dZSbot::Root core updatecheck.tcl]
source [file join $::dZSbot::Root core bootstrap.tcl]

::dZSbot::Bootstrap::Start
