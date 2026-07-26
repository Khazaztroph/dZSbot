set root [file normalize [pwd]]

source [file join $root dZSbot.tcl]

set preTestFile [file join $root runtime test-pre-stats.tsv]
catch {file delete $preTestFile}
::dZSbot::Config::Set pre.storage $preTestFile
::dZSbot::Config::Set pre.daily_stats.window_hours 24
::dZSbot::Config::Set pre.daily_stats.top_limit 3

set now [clock seconds]
set old [expr {$now - (48 * 3600)}]

::dZSbot::Modules::Pre::Store::AddEntry [dict create section MOVIES relname Movie.One-GRP u_name user g_name GRP nukereason "" pretime $now size 1048576 files 10]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section MUSIC relname Album.One-GRP u_name user g_name GRP nukereason "" pretime $now size 524288 files 8]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section MUSIC relname Album.Two-OTHER u_name user g_name OTHER nukereason "" pretime $now size 1024 files 2]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section EBOOKS relname Book.One-GRP u_name user g_name GRP nukereason "" pretime $now size 2048 files 3]
::dZSbot::Modules::Pre::Store::AddEntry [dict create section TV relname Old.Show-GRP u_name user g_name GRP nukereason "" pretime $old size 999999 files 99]

set lines [::dZSbot::Modules::Pre::DailyStatsLines]
foreach line $lines {
    puts $line
}

set joined [join $lines "\n"]
if {[string first "4 releases" $joined] < 0} {
    error "Expected daily stats to include only recent releases"
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
        error "Expected every PRE stats line to use the active theme: $themedLine"
    }
}
