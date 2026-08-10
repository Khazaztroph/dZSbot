set root [file normalize [pwd]]

package require sqlite3

source [file join $root dZSbot.tcl]

if {[llength [info commands sqlite3]] == 0} {
    puts "Skipping nxTools import test: sqlite3 Tcl command is unavailable in this runtime"
    return
}

set sourceDb [file join $root runtime "test-nxtools-pres-[pid].db"]
set targetFile [file join $root runtime "test-pre-import-[pid].tsv"]
catch {file delete $sourceDb}
catch {file delete $targetFile}

sqlite3 db $sourceDb
db eval {
    CREATE TABLE Pres(
        TimeStamp INTEGER default 0,
        UserName  TEXT default '',
        GroupName TEXT default '',
        Area      TEXT default '',
        Release   TEXT default '',
        Files     INTEGER default 0,
        Size      INTEGER default 0
    )
}
db eval {
    INSERT INTO Pres(TimeStamp,UserName,GroupName,Area,Release,Files,Size)
    VALUES(1800000000,'khaz','MEV','MUSIC','Example.Release.FLAC-GROUP',5,82865)
}
db eval {
    INSERT INTO Pres(TimeStamp,UserName,GroupName,Area,Release,Files,Size)
    VALUES(1800000001,'other','OTHER','MUSIC','example.release.flac-group',5,82865)
}
db close

::dZSbot::Config::Set pre.backend "tsv"
::dZSbot::Config::Set pre.storage $targetFile

set candidates [::dZSbot::Modules::Pre::NxTools::CandidatePaths "C:/ioFTPD/scripts/nxTools/data/Pres.db"]
if {[lsearch -exact $candidates "/cygdrive/c/ioFTPD/scripts/nxTools/data/Pres.db"] < 0} {
    error "Expected Cygwin nxTools path candidate: $candidates"
}

set realDb "C:/ioFTPD/scripts/nxTools/data/Pres.db"
set realCandidates [::dZSbot::Modules::Pre::NxTools::CandidatePaths $realDb]
set existingRealDb ""
foreach candidate $realCandidates {
    if {[file exists $candidate]} {
        set existingRealDb $candidate
        break
    }
}
if {$existingRealDb ne ""} {
    set dbName ::dZSbot::Tests::RealNxToolsPresDb
    catch {$dbName close}
    set opened [::dZSbot::Modules::Pre::NxTools::OpenPresDb $dbName $realDb]
    catch {$dbName close}
    if {![dict get $opened ok]} {
        error "Expected real nxTools Pres.db to open through snapshot: $opened"
    }
}

set result [::dZSbot::Modules::Pre::NxTools::ImportPres $sourceDb]
if {![dict get $result ok] || [dict get $result imported] != 1 || [dict get $result skipped] != 1} {
    error "Expected one import and one in-file duplicate skip: $result"
}

set rows [::dZSbot::Modules::Pre::Store::SearchEntries Example.Release 5]
if {[llength $rows] != 1} {
    error "Expected exactly one imported PRE row: $rows"
}

set repeated [::dZSbot::Modules::Pre::NxTools::ImportPres $sourceDb]
if {![dict get $repeated ok] || [dict get $repeated imported] != 0 || [dict get $repeated skipped] != 2} {
    error "Expected repeated import to skip both existing releases: $repeated"
}

puts "Imported nxTools PRE: [lindex $rows 0]"
