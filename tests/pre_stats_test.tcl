set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set preTestFile [file join $root runtime "test-pre-stats-[pid].tsv"]
catch {file delete $preTestFile}
::dZSbot::Config::Set pre.storage $preTestFile
::dZSbot::Config::Set pre.daily_stats.periods {day week month}
::dZSbot::Config::Set pre.daily_stats.top_limit 3
::dZSbot::Config::Set theme.irc.colors 0

set now [clock seconds]
set old [expr {$now - (48 * 3600)}]
set older [expr {$now - (10 * 86400)}]

::dZSbot::Modules::Pre::Store::AddEntry [dict create section MOVIES relname Movie.One-GRP u_name user g_name GRP nukereason "" pretime $now size 1048576 files 10]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section MUSIC relname Album.One-GRP u_name user g_name GRP nukereason "" pretime $now size 524288 files 8]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section MUSIC relname Album.Two-OTHER u_name user g_name OTHER nukereason "" pretime $now size 1024 files 2]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section EBOOKS relname Book.One-GRP u_name user g_name GRP nukereason "" pretime $now size 2048 files 3]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section TV relname Old.Show-GRP u_name user g_name GRP nukereason "" pretime $old size 999999 files 99]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section GAMES relname Older.Game-GRP u_name user g_name GRP nukereason "" pretime $older size 4096 files 4]

set lines [::dZSbot::Modules::Pre::DailyStatsLines]
foreach line $lines {
    puts $line
}

set joined [join $lines "\n"]
if {[string first "4 releases" $joined] < 0} {
    error "Expected daily stats to include only recent releases"
}
if {[string first "PRE Daily Stats: last 24h | 4 releases" $joined] < 0} {
    error "Expected day stats header"
}
if {[string first "PRE Weekly Stats: last 7d | 5 releases" $joined] < 0} {
    error "Expected week stats to include 48h-old release"
}
if {[string first "PRE Monthly Stats: last 30d | 6 releases" $joined] < 0} {
    error "Expected month stats to include 10d-old release"
}
if {[string first "GRP (3)" $joined] < 0} {
    error "Expected GRP to be top group"
}
if {[string first "MUSIC (2)" $joined] < 0} {
    error "Expected MUSIC to be top section"
}

::dZSbot::Config::Set theme.irc.colors 1
set themedLines [::dZSbot::Modules::Pre::DailyStatsLines]
foreach themedLine $themedLines {
    if {[string first "\003" $themedLine] < 0} {
        error "Expected every PRE stats line to include color when colors are enabled: $themedLine"
    }
}
