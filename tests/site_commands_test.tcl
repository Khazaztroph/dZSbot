set root [file normalize [pwd]]

proc ioftpd {command messageWindow fields} {
    if {$command ne "who"} {
        error "unexpected ioftpd command: $command"
    }
    return [list \
        [list 1 user1 GROUP 2048 /MOVIES/Example.Release-GRP] \
        [list 0 user2 GROUP 0 /TV/Idle.Show-GRP]]
}

source [file join $root dZSbot.tcl]

set tempSection [file join $root runtime]
::dZSbot::Config::Set site.df.sections [list [list RUNTIME $tempSection]]
::dZSbot::Config::Set site.commands.df.source "local"
::dZSbot::Config::Set site.commands.bw.source "ioftpd"

set commands [::dZSbot::Commands::List site]
if {"!df" ni $commands || "!bw" ni $commands} {
    error "Expected !df and !bw to be registered by site module: $commands"
}

set bw [::dZSbot::Modules::Site::TransferSample]
if {![dict get $bw available]} {
    error "Expected mocked ioftpd who to be available"
}
if {[dict get $bw active] != 1 || [dict get $bw total] != 2} {
    error "Unexpected BW sample: $bw"
}

set cacheFile [file join $root runtime test-bw.tsv]
set fh [open $cacheFile w]
fconfigure $fh -encoding utf-8 -translation lf
set now [clock seconds]
puts $fh "# dZSbot-bw-v1\t$now"
puts $fh [join [list $now upload user1 GROUP 2048 /MOVIES/Example.Release-GRP D:/site/MOVIES/Example.Release-GRP STOR] "\t"]
puts $fh [join [list $now download user2 GROUP 1024 /TV/Example.Show-GRP D:/site/TV/Example.Show-GRP RETR] "\t"]
puts $fh [join [list $now idle user3 GROUP 0 /IDLE "" IDLE] "\t"]
close $fh

::dZSbot::Config::Set site.commands.bw.source "cache"
::dZSbot::Config::Set site.commands.bw.cache_file $cacheFile
::dZSbot::Config::Set site.commands.bw.cache_max_age_seconds 30
set cacheBw [::dZSbot::Modules::Site::TransferSample]
if {![dict get $cacheBw available]} {
    error "Expected BW cache to be available: $cacheBw"
}
if {[dict get $cacheBw active] != 2 || [dict get $cacheBw total] != 3} {
    error "Unexpected BW cache sample: $cacheBw"
}
if {![string match "*UP 1 @ 2.00 MB/s | DN 1 @ 1.00 MB/s*" [dict get $cacheBw summary]]} {
    error "Unexpected BW cache summary: $cacheBw"
}

set df [::dZSbot::Modules::Site::DiskFree $tempSection]
if {![dict get $df ok]} {
    error "Expected runtime disk free to be readable: $df"
}

set dfCacheFile [file join $root runtime test-df.tsv]
set fh [open $dfCacheFile w]
fconfigure $fh -encoding utf-8 -translation lf
puts $fh "# dZSbot-df-v1\t$now"
puts $fh [join [list $now RUNTIME $tempSection 1024 2048 3072 ""] "\t"]
puts $fh [join [list $now BROKEN /missing 0 0 0 "path not found"] "\t"]
close $fh

::dZSbot::Config::Set site.commands.df.source "cache"
::dZSbot::Config::Set site.commands.df.cache_file $dfCacheFile
::dZSbot::Config::Set site.commands.df.cache_max_age_seconds 30
set dfCacheLines [::dZSbot::Modules::Site::DfCacheLines ""]
if {![dict get $dfCacheLines ok] || [llength [dict get $dfCacheLines lines]] != 2} {
    error "Expected DF cache lines: $dfCacheLines"
}

set broken [::dZSbot::Modules::Site::ParseDfSection {BROKEN "C:/missing/path}]
if {[dict get $broken ok]} {
    error "Expected broken DF section to be reported as invalid"
}

::dZSbot::Config::Set site.df.sections [dict create RUNTIME $tempSection]
set dictSections [::dZSbot::Modules::Site::DfSections]
if {![llength $dictSections] || ![dict get [lindex $dictSections 0] ok]} {
    error "Expected dict-style DF sections to parse: $dictSections"
}

set trafficLines [::dZSbot::Modules::Site::ParseSiteCommandLines {
    {200-| [Stats]}
    {200-| STATS - Show transfer statistics.}
    {200-| TRAFFIC - Display traffic statistics for user/group/all.}
    {200 Command successful.}
}]
if {[llength $trafficLines] < 2} {
    error "Expected SITE traffic parser to keep useful lines: $trafficLines"
}

set siteSample [dict create available 1 total 0 active 0 speed 0 lines {{"BW: Total traffic: 0 @ 0 Mbps"}} error "" type site]
if {[::dZSbot::Modules::Site::DictGet $siteSample type ""] ne "site"} {
    error "Expected site sample type helper to work"
}

::dZSbot::Commands::Dispatch !bw tester host hand #chan ""
::dZSbot::Commands::Dispatch !df tester host hand #chan "runtime"
