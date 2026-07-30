set root [file normalize [pwd]]

set ::updateTimers {}
proc utimer {delay callback} {
    lappend ::updateTimers [list $delay $callback]
    return [llength $::updateTimers]
}

source [file join $root dZSbot.tcl]

if {[::dZSbot::UpdateCheck::CompareVersions v2.0.9 2.0.8] != 1} {
    error "Expected v2.0.9 to be newer than 2.0.8"
}
if {[::dZSbot::UpdateCheck::CompareVersions 2.0.7 2.0.7] != 0} {
    error "Expected equal versions"
}
if {[::dZSbot::UpdateCheck::CompareVersions 2.0.6 2.0.7] != -1} {
    error "Expected 2.0.6 to be older than 2.0.7"
}

set cacheFile [file join $root runtime test-update-check.tsv]
catch {file delete $cacheFile}
::dZSbot::Config::Set update_check.cache_file $cacheFile
::dZSbot::Config::Set update_check.channel ""
::dZSbot::Config::Set status.admin_channel "#staff"
::dZSbot::Config::Set update_check.interval_seconds 86400

rename ::dZSbot::UpdateCheck::Fetch ::dZSbot::UpdateCheck::FetchReal
proc ::dZSbot::UpdateCheck::Fetch {} {
    return [dict create ok 1 latest 99.0.0 url https://example.test/release]
}

set ::updateReplies {}
rename ::dZSbot::Commands::Reply ::dZSbot::Commands::ReplyReal
proc ::dZSbot::Commands::Reply {nick chan message} {
    lappend ::updateReplies [list $nick $chan $message]
}

set result [::dZSbot::UpdateCheck::Run]
if {![dict get $result ok] || [llength $::updateReplies] != 1} {
    error "Expected one update notification: $result / $::updateReplies"
}
if {[lindex [lindex $::updateReplies 0] 1] ne "#staff"} {
    error "Expected update notification in admin channel: $::updateReplies"
}
if {![file exists $cacheFile]} {
    error "Expected persistent update-check cache"
}

set ::updateReplies {}
proc ::dZSbot::UpdateCheck::Fetch {} {
    return [dict create ok 1 latest $::dZSbot::Version url https://example.test/current]
}
::dZSbot::UpdateCheck::Run
if {[llength $::updateReplies] != 0} {
    error "Current version must not produce an admin notification"
}

puts "Daily update check passed"
