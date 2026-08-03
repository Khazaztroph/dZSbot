set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set adapter [::dZSbot::SiteAdapter::Get fluxftp]
if {![dict exists $adapter namespace] || [dict get $adapter namespace] ne "::dZSbot::Adapter::FluxFTP"} {
    error "Expected FluxFTP adapter to be registered: $adapter"
}

::dZSbot::Config::Set fluxftp.enabled 1
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:8080/api/"
::dZSbot::Config::Set fluxftp.api_key "secret"

proc MockFluxHttpGet {url headers} {
    set ::MockFluxLastUrl $url
    set ::MockFluxLastHeaders $headers

    if {[string match */health $url]} {
        return [dict create ok 1 code 200 error "" data [dict create status ok version 1.0.0]]
    }
    if {[string match */transfers $url]} {
        return [dict create ok 1 code 200 error "" data [dict create transfers [list \
            [dict create direction upload user racer group GROUP speed_kbps 2048 path /MUSIC/Release-GRP] \
            [dict create direction download user leecher group GROUP speed_kbps 1024 path /TV/Show-GRP] \
            [dict create direction idle user idle group GROUP speed_kbps 0 path /]]]]
    }
    if {[string match */sections $url]} {
        return [dict create ok 1 code 200 error "" data [dict create sections [list \
            [dict create name MOVIES path /MOVIES free_mb 1024 used_mb 2048 total_mb 3072]]]]
    }
    if {[string match */users $url]} {
        return [dict create ok 1 code 200 error "" data [dict create users [list \
            [dict create username racer group GROUP status online virtual_path /MUSIC]]]]
    }
    if {[string match */uploads/recent $url]} {
        return [dict create ok 1 code 200 error "" data [dict create uploads [list \
            [dict create name Example.Release-GROUP section MOVIES path /MOVIES/Example.Release-GROUP user racer group GROUP files 10 size_kb 1024]]]]
    }
    if {[string match */pre* $url]} {
        return [dict create ok 1 code 200 error "" data [dict create releases [list \
            [dict create release Example.Pre-GROUP section MOVIES path /MOVIES/Example.Pre-GROUP user racer group GROUP files 10 size_kb 1024]]]]
    }

    return [dict create ok 0 code 404 error "not found" data {}]
}

::dZSbot::Adapter::FluxFTP::SetHttpGetCommand MockFluxHttpGet

set health [::dZSbot::Adapter::FluxFTP::Health]
if {![dict get $health ok] || [dict get $health status] ne "ok"} {
    error "Expected FluxFTP health OK: $health"
}

set bw [::dZSbot::Adapter::FluxFTP::Bandwidth]
if {![dict get $bw ok] || [dict get $bw upload_count] != 1 || [dict get $bw download_count] != 1} {
    error "Expected normalized FluxFTP bandwidth: $bw"
}
if {[dict get $bw total_speed_kbps] != 3072} {
    error "Expected FluxFTP total speed 3072 KB/s: $bw"
}

proc MockFluxCbftpHttpGet {url headers} {
    if {[string match */transfers $url]} {
        return [dict create ok 0 code 404 error "HTTP 404 (ok)" data {}]
    }
    if {[string match */transferjobs $url]} {
        return [dict create ok 1 code 200 error "" data [dict create transferjobs [list \
            [dict create status running user cbuser group CBGROUP average_speed 2.5 name Cbftp.Release-GRP] \
            [dict create status done user cbuser group CBGROUP average_speed 0 name Done.Release-GRP]]]]
    }
    return [dict create ok 0 code 404 error "not found" data {}]
}

::dZSbot::Adapter::FluxFTP::SetHttpGetCommand MockFluxCbftpHttpGet
set cbftpBw [::dZSbot::Adapter::FluxFTP::Bandwidth]
if {![dict get $cbftpBw ok] || [dict get $cbftpBw endpoint] ne "transferjobs"} {
    error "Expected FluxFTP bandwidth to fall back to transferjobs: $cbftpBw"
}
if {[dict get $cbftpBw transfer_count] != 1 || [dict get $cbftpBw total_speed_kbps] != 2560.0} {
    error "Expected CBFTP average_speed MB/s to normalize to KB/s: $cbftpBw"
}

::dZSbot::Adapter::FluxFTP::SetHttpGetCommand MockFluxHttpGet

set df [::dZSbot::Adapter::FluxFTP::DiskFree]
if {![dict get $df ok] || [dict get [lindex [dict get $df sections] 0] name] ne "MOVIES"} {
    error "Expected normalized FluxFTP disk free: $df"
}

set users [::dZSbot::Adapter::FluxFTP::Users]
if {![dict get $users ok] || [dict get [lindex [dict get $users users] 0] user] ne "racer"} {
    error "Expected normalized FluxFTP users: $users"
}

set uploads [::dZSbot::Adapter::FluxFTP::RecentUploads]
if {![dict get $uploads ok] || [dict get [lindex [dict get $uploads uploads] 0] release] ne "Example.Release-GROUP"} {
    error "Expected normalized FluxFTP uploads: $uploads"
}

set pre [::dZSbot::Adapter::FluxFTP::PreSearch Example 5]
if {![dict get $pre ok] || [dict get [lindex [dict get $pre releases] 0] source] ne "FluxFTP-PRE"} {
    error "Expected normalized FluxFTP PRE results: $pre"
}

if {![string match "http://127.0.0.1:8080/api/pre?*" $::MockFluxLastUrl]} {
    error "Expected FluxFTP query URL under base_url, got $::MockFluxLastUrl"
}
array set mockHeaders $::MockFluxLastHeaders
if {![info exists mockHeaders(Authorization)] || $mockHeaders(Authorization) ne "Bearer secret"} {
    error "Expected FluxFTP Authorization header: $::MockFluxLastHeaders"
}

::dZSbot::Config::Set fluxftp.auth_scheme "Basic"
::dZSbot::Config::Set fluxftp.api_key "secret"
array unset mockHeaders
array set mockHeaders [::dZSbot::Adapter::FluxFTP::Headers]
if {![info exists mockHeaders(Authorization)] || $mockHeaders(Authorization) ne "Basic OnNlY3JldA=="} {
    error "Expected FluxFTP Basic password auth header: [array get mockHeaders]"
}

::dZSbot::Config::Set fluxftp.base_url "https://127.0.0.1:55477/api"
if {[catch {::dZSbot::Adapter::FluxFTP::EnsureHttp} error]} {
    puts "Skipping live HTTPS transport registration check: $error"
}
