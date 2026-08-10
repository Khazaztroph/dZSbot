set root [file normalize [pwd]]
source [file join $root dZSbot.tcl]

set preTestFile [file join $root runtime "test-pre-duplicate-[pid].tsv"]
catch {file delete $preTestFile}
::dZSbot::Config::Set pre.backend "tsv"
::dZSbot::Config::Set pre.storage $preTestFile

::dZSbot::Modules::Pre::Store::AddEntry [dict create \
    section MUSIC relname Example.Release-GROUP u_name tester g_name GROUP \
    nukereason "" size 1024 files 1]

if {![::dZSbot::Modules::Pre::Store::Exists example.release-group]} {
    error "Expected case-insensitive TSV duplicate lookup"
}
if {[::dZSbot::Modules::Pre::Store::Exists Missing.Release-GROUP]} {
    error "Unexpected TSV duplicate match"
}

rename ::dZSbot::Modules::Pre::MySQLStore::Ensure ::dZSbot::Modules::Pre::MySQLStore::EnsureReal
proc ::dZSbot::Modules::Pre::MySQLStore::Ensure {} {
    return 1
}

rename ::dZSbot::Database::MySQL::SelectFlat ::dZSbot::Database::MySQL::SelectFlatReal
proc ::dZSbot::Database::MySQL::SelectFlat {sql} {
    set ::duplicateSql $sql
    if {[string first "'Existing.Release-GROUP'" $sql] >= 0} {
        return {42}
    }
    return {}
}

::dZSbot::Config::Set pre.backend "mysql"
if {![::dZSbot::Modules::Pre::Store::Exists Existing.Release-GROUP]} {
    error "Expected exact MySQL duplicate lookup"
}
if {[::dZSbot::Modules::Pre::Store::Exists Missing.Release-GROUP]} {
    error "Unexpected MySQL duplicate match"
}
if {[string first {WHERE `relname` = 'Missing.Release-GROUP' LIMIT 1} $::duplicateSql] < 0} {
    error "Expected an exact indexed relname query: $::duplicateSql"
}

puts "PRE duplicate detection passed for TSV and MySQL"
