set root [file normalize [pwd]]
source [file join $root dZSbot.tcl]

set preTestFile [file join $root runtime test-pre-remote.tsv]
catch {file delete $preTestFile}
::dZSbot::Config::Set pre.backend "tsv"
::dZSbot::Config::Set pre.storage $preTestFile
::dZSbot::Config::Set pre.remote.enabled 1

rename ::dZSbot::Modules::Pre::Remote::Fetch ::dZSbot::Modules::Pre::Remote::FetchReal
proc ::dZSbot::Modules::Pre::Remote::Fetch {query {type ""}} {
    return [dict create ok 1 data {
        {
          "status": "success",
          "results": 1,
          "data": [{
            "id": 123,
            "pretime": 1700000000,
            "release": "Remote.Release-GROUP",
            "section": "TV",
            "files": 12,
            "size": 1024,
            "status": 1,
            "reason": "dupe",
            "group": "GROUP"
          }]
        }
    }]
}

set remote [::dZSbot::Modules::Pre::Remote::Search Remote.Release 5]
if {![dict get $remote ok] || [llength [dict get $remote rows]] != 1} {
    error "Expected one normalized PreDB.net result: $remote"
}

set row [lindex [dict get $remote rows] 0]
if {[dict get $row relname] ne "Remote.Release-GROUP"} {
    error "Unexpected remote release: $row"
}
if {[dict get $row g_name] ne "GROUP" || [dict get $row nukereason] ne "dupe"} {
    error "Expected group and nuke data to be normalized: $row"
}
if {[dict get $row size] != 1048576} {
    error "Expected PreDB.net MB size to be normalized to dZSbot KB: $row"
}

set local [::dZSbot::Modules::Pre::Store::AddEntry [dict create \
    section MOVIES relname Local.Release-GROUP u_name tester g_name GROUP \
    nukereason "" size 2048 files 2]]

set ::remoteCalls 0
rename ::dZSbot::Modules::Pre::Remote::Search ::dZSbot::Modules::Pre::Remote::SearchReal
proc ::dZSbot::Modules::Pre::Remote::Search {query {limit 5} {type ""}} {
    incr ::remoteCalls
    return [dict create ok 1 rows {}]
}

::dZSbot::Modules::Pre::CmdPre tester host hand #chan Local.Release
if {$::remoteCalls != 0} {
    error "Remote fallback must not run when the local database has a match"
}

::dZSbot::Modules::Pre::CmdPre tester host hand #chan Missing.Release
if {$::remoteCalls != 1} {
    error "Remote fallback must run once when the local database has no match"
}

puts "PreDB.net remote lookup and local-first fallback passed"
