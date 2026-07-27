set root [file normalize [pwd]]
source [file join $root dZSbot.tcl]

if {![llength [info commands ::dZSbot::Bootstrap::StartUpdateCheck]]} {
    error "Expected guarded update-check bootstrap helper"
}
