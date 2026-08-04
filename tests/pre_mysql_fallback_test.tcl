set root [file normalize [pwd]]
source [file join $root dZSbot.tcl]

set fallbackFile [file join $root runtime test-pre-mysql-fallback.tsv]
catch {file delete $fallbackFile}

::dZSbot::Config::Set pre.backend "mysql"
::dZSbot::Config::Set pre.storage $fallbackFile
::dZSbot::Config::Set pre.mysql.fallback_to_tsv 1

rename ::dZSbot::Modules::Pre::MySQLStore::Search ::dZSbot::Modules::Pre::MySQLStore::SearchReal
rename ::dZSbot::Modules::Pre::MySQLStore::Latest ::dZSbot::Modules::Pre::MySQLStore::LatestReal

proc ::dZSbot::Modules::Pre::MySQLStore::Search {query {limit 10}} {
    return {}
}

proc ::dZSbot::Modules::Pre::MySQLStore::Latest {{limit 10}} {
    return {}
}

::dZSbot::Modules::Pre::Store::Add [dict create \
    section MOVIES \
    relname Fallback.Release-GROUP \
    u_name tester \
    g_name GROUP \
    nukereason "" \
    size 1024 \
    files 1]

set latest [::dZSbot::Modules::Pre::Store::LatestEntries 5]
if {[llength $latest] != 1 || [dict get [lindex $latest 0] relname] ne "Fallback.Release-GROUP"} {
    error "Expected !pres MySQL mode to read TSV fallback rows: $latest"
}

set search [::dZSbot::Modules::Pre::Store::SearchEntries Fallback 5]
if {[llength $search] != 1 || [dict get [lindex $search 0] relname] ne "Fallback.Release-GROUP"} {
    error "Expected !pre MySQL mode to read TSV fallback rows: $search"
}

::dZSbot::Config::Set pre.mysql.fallback_to_tsv 0
set disabled [::dZSbot::Modules::Pre::Store::LatestEntries 5]
if {[llength $disabled] != 0} {
    error "Expected TSV fallback to be disabled: $disabled"
}

puts "PRE MySQL TSV read fallback passed"
