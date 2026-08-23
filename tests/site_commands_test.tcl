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
foreach expected {!df !bw !bnc !quota !weekly !approve !nuke !unnuke !unuke !reqfilled !reqdel !incomplete !incompletes} {
    if {$expected ni $commands} {
        error "Expected $expected to be registered by site module: $commands"
    }
}

if {"!topic" in $commands} {
    error "Did not expect !topic to be registered by site module: $commands"
}

proc MockBncCheck {target} {
    set name [string toupper [dict get $target name]]
    if {$name eq "PRIMEBNC"} {
        return [dict create ok 1 ms 12 error ""]
    }
    return [dict create ok 0 ms 0 error "connection refused"]
}

::dZSbot::Config::Set site.commands.bnc.targets {
    {PRiMEBNC 127.0.0.1 31337}
    {BackupBNC 127.0.0.1 31338}
}
::dZSbot::Modules::Site::SetBncCheckCommand MockBncCheck

set bncLines [::dZSbot::Modules::Site::BncLines ""]
if {[lindex $bncLines 0] ne "BNC: 1/2 online"} {
    error "Unexpected BNC summary: $bncLines"
}
if {![string match "*BNC: PRIMEBNC | OK | 127.0.0.1:31337 | 12ms*" [join $bncLines "\n"]]} {
    error "Expected online BNC target: $bncLines"
}
if {![string match "*BNC: BACKUPBNC | DOWN | 127.0.0.1:31338 | connection refused*" [join $bncLines "\n"]]} {
    error "Expected down BNC target: $bncLines"
}

set filteredBnc [::dZSbot::Modules::Site::BncLines "prime"]
if {[llength $filteredBnc] != 2 || [lindex $filteredBnc 0] ne "BNC: 1/1 online"} {
    error "Unexpected filtered BNC output: $filteredBnc"
}

set eggdropTarget [::dZSbot::Modules::Site::ParseBncTarget {ZNC eggdrop 0}]
if {![dict get $eggdropTarget ok] || [dict get $eggdropTarget mode] ne "eggdrop"} {
    error "Expected eggdrop BNC target to parse: $eggdropTarget"
}

set quotaFile [file join $root runtime "test-quota-[pid].tsv"]
set fh [open $quotaFile w]
fconfigure $fh -encoding utf-8 -translation lf
puts $fh [join [list aCe pass 605.92 169.76] "\t"]
puts $fh [join [list foyel pass 509.75 114.82] "\t"]
puts $fh [join [list rrimul pass 481.37 139.27] "\t"]
puts $fh [join [list trax pass 471.39 90.47] "\t"]
puts $fh [join [list NasBanH pass 416.25 129.11] "\t"]
close $fh

::dZSbot::Config::Set site.commands.quota.cache_file $quotaFile
::dZSbot::Config::Set site.commands.quota.cache_max_age_seconds 30
::dZSbot::Config::Set site.commands.quota.server_name "SomeServer"
::dZSbot::Config::Set site.commands.quota.required_gb 121.18
::dZSbot::Config::Set site.commands.quota.days_left 4
::dZSbot::Config::Set site.commands.quota.limit 5
::dZSbot::Config::Set site.commands.quota.dayup_limit 3
::dZSbot::Config::Set site.commands.quota.channel "#monstra"

set quotaLines [::dZSbot::Modules::Site::QuotaLines]
if {[lindex $quotaLines 0] ne {[ SomeServer]-[ QUOTA 121.18/GB ]-[ Weekly 20% top-1 ]-[ 4 DAYS LEFT ]}} {
    error "Unexpected quota header: $quotaLines"
}
if {![string match "*01: aCe pass with 605.92 GB | today: 169.76 GB (#1 DAYUP)*" [join $quotaLines "\n"]]} {
    error "Expected first quota row with DAYUP: $quotaLines"
}
if {![string match "*03: rrimul pass with 481.37 GB | today: 139.27 GB (#2 DAYUP)*" [join $quotaLines "\n"]]} {
    error "Expected third quota row with DAYUP: $quotaLines"
}
if {![string match "*FAIL Who will die this time? R.I.P*" [join $quotaLines "\n"]]} {
    error "Expected quota fail footer: $quotaLines"
}

set incompleteFile [file join $root runtime "test-incomplete-[pid].tsv"]
set fh [open $incompleteFile w]
fconfigure $fh -encoding utf-8 -translation lf
puts $fh [join [list [clock seconds] MOVIES Example.Incomplete-GRP /MOVIES/Example.Incomplete-GRP tester GROUP] "\t"]
close $fh
::dZSbot::Config::Set site.commands.incomplete.cache_file $incompleteFile
::dZSbot::Config::Set site.commands.incomplete.cache_max_age_seconds 30
set incompleteLines [::dZSbot::Modules::Site::IncompleteLines MOVIES]
if {![string match "*INCOMPLETE: MOVIES | Example.Incomplete-GRP*" [join $incompleteLines "\n"]]} {
    error "Expected incomplete cache line: $incompleteLines"
}

set ::quotaReplies {}
proc puthelp {line} {
    lappend ::quotaReplies $line
}
::dZSbot::Modules::Site::CmdQuota tester host hand #staff ""
rename puthelp {}
if {![llength $::quotaReplies] || ![string match {PRIVMSG #monstra :*} [lindex $::quotaReplies 0]]} {
    error "Expected quota command to reply in #monstra: $::quotaReplies"
}

set bw [::dZSbot::Modules::Site::TransferSample]
if {![dict get $bw available]} {
    error "Expected mocked ioftpd who to be available"
}
if {[dict get $bw active] != 1 || [dict get $bw total] != 2} {
    error "Unexpected BW sample: $bw"
}

set cacheFile [file join $root runtime "test-bw-[pid].tsv"]
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

proc FluxFtpSiteMock {url headers} {
    if {[string match "*/transfers" $url]} {
        return [dict create ok 1 code 200 error "" data [dict create transfers [list \
            [dict create direction upload user fluxup group API speed_kbps 4096 path /MOVIES/Flux.Release-GRP] \
            [dict create direction download user fluxdn group API speed_kbps 1024 path /TV/Flux.Show-GRP] \
            [dict create direction idle user fluxidle group API speed_kbps 0 path /IDLE]]]]
    }
    if {[string match "*/sections" $url]} {
        return [dict create ok 1 code 200 error "" data [dict create sections [list \
            [dict create name MOVIES path /MOVIES free_mb 2048 used_mb 2048 total_mb 4096] \
            [dict create name TV path /TV free_mb 1024 used_mb 3072 total_mb 4096]]]]
    }
    return [dict create ok 0 code 404 error "unexpected URL $url" data {}]
}

::dZSbot::Config::Set fluxftp.enabled 1
::dZSbot::Config::Set fluxftp.base_url "http://127.0.0.1:55477/api"
::dZSbot::Adapter::FluxFTP::SetHttpGetCommand FluxFtpSiteMock
::dZSbot::Config::Set site.commands.bw.source "fluxftp"
set fluxBw [::dZSbot::Modules::Site::TransferSample]
if {![dict get $fluxBw available] || [dict get $fluxBw active] != 2 || [dict get $fluxBw total] != 3} {
    error "Expected FluxFTP BW sample: $fluxBw"
}
if {![string match "*UP 1 @ 4.00 MB/s | DN 1 @ 1.00 MB/s*" [dict get $fluxBw summary]]} {
    error "Unexpected FluxFTP BW summary: $fluxBw"
}

set df [::dZSbot::Modules::Site::DiskFree $tempSection]
if {![dict get $df ok]} {
    error "Expected runtime disk free to be readable: $df"
}

set dfCacheFile [file join $root runtime "test-df-[pid].tsv"]
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

::dZSbot::Config::Set site.commands.df.source "fluxftp"
set fluxDf [::dZSbot::Modules::Site::FluxFtpDfLines "MOVIES"]
if {![dict get $fluxDf ok] || [llength [dict get $fluxDf lines]] != 1} {
    error "Expected FluxFTP DF line: $fluxDf"
}
if {![string match "*DF: MOVIES | free 2.00 GB / total 4.00 GB*" [lindex [dict get $fluxDf lines] 0]]} {
    error "Unexpected FluxFTP DF output: $fluxDf"
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

::dZSbot::Config::Set site.commands.df.source "cache"
::dZSbot::Commands::Dispatch !bw tester host hand #chan ""
::dZSbot::Commands::Dispatch !df tester host hand #chan "runtime"
::dZSbot::Commands::Dispatch !BNC tester host hand #chan ""
::dZSbot::Commands::Dispatch !QUOTA tester host hand #chan ""
