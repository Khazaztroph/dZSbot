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

proc FluxFtpPreMock {url headers} {
    if {![string match "*/pre?*" $url]} {
        return [dict create ok 0 code 404 error "unexpected URL $url" data {}]
    }

    return [dict create ok 1 code 200 error "" data [dict create releases [list [dict create \
        release Flux.Release-GROUP \
        section GAMES \
        user fluxuser \
        group GROUP \
        files 42 \
        size 8192 \
        pretime 1700000000]]]]
}

::dZSbot::Config::Set fluxftp.enabled 1
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:55477/api"
::dZSbot::Config::Set pre.fluxftp.enabled 1
::dZSbot::Config::Set pre.fluxftp.mode "read"
::dZSbot::Adapter::FluxFTP::SetHttpGetCommand FluxFtpPreMock
set ::remoteCalls 0
::dZSbot::Modules::Pre::CmdPre tester host hand #chan Flux.Release
if {$::remoteCalls != 0} {
    error "PreDB fallback must not run when FluxFTP fallback returns a match"
}

set fluxRows [::dZSbot::Modules::Pre::FluxFtpSearchRows Flux.Release 5]
if {[llength $fluxRows] != 1} {
    error "Expected one FluxFTP PRE row: $fluxRows"
}
set fluxRow [lindex $fluxRows 0]
if {[dict get $fluxRow relname] ne "Flux.Release-GROUP" || [dict get $fluxRow u_name] ne "fluxuser"} {
    error "Unexpected FluxFTP PRE normalization: $fluxRow"
}
if {[dict get $fluxRow pretime] != 1700000000} {
    error "Expected FluxFTP PRE timestamp to be preserved: $fluxRow"
}

puts "PreDB.net remote lookup and local-first fallback passed"
