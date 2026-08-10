set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set requestTestFile [file join $root runtime "test-requests-module-[pid].tsv"]
catch {file delete $requestTestFile}
::dZSbot::Config::Set request.storage $requestTestFile
::dZSbot::Config::Set requests.list_limit 5

set first [::dZSbot::Modules::Requests::Store::Add tester "Movie.Request.2026"]
set second [::dZSbot::Modules::Requests::Store::Add other "Album.Request.2026"]

puts [::dZSbot::Modules::Requests::Formatter::Added $first]

set open [::dZSbot::Modules::Requests::Store::Open 10]
if {[llength $open] != 2} {
    error "Expected two open requests"
}

puts [::dZSbot::Modules::Requests::Formatter::Header [::dZSbot::Modules::Requests::Store::CountOpen]]
puts [::dZSbot::Modules::Requests::Formatter::Line [lindex $open 0] 1]

set filled [::dZSbot::Modules::Requests::Store::Fill Movie filler]
if {$filled eq "" || [dict get $filled status] ne "filled"} {
    error "Expected request to be filled"
}
puts [::dZSbot::Modules::Requests::Formatter::Filled $filled]

set deleted [::dZSbot::Modules::Requests::Store::Delete Album]
if {[llength $deleted] != 1} {
    error "Expected request to be deleted"
}
puts [::dZSbot::Modules::Requests::Formatter::Deleted [lindex $deleted 0]]

if {[::dZSbot::Modules::Requests::Store::CountOpen] != 0} {
    error "Expected no open requests"
}
